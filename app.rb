require 'sinatra'
require 'killbill_client'

set :kb_url, ENV['KB_URL'] || 'http://127.0.0.1:8080'
set :encryption_token, ENV['ENCRYPTION_TOKEN']

#
# Kill Bill configuration and helpers
#

KillBillClient.url = settings.kb_url

# Multi-tenancy and RBAC credentials
options = {
    :username => 'admin',
    :password => 'password',
    :api_key => 'bob',
    :api_secret => 'lazar'
}

# Audit log data
user = 'demo'
reason = 'New subscription'
comment = 'Trigger by Sinatra'

def create_kb_account(user, reason, comment, options)
  account = KillBillClient::Model::Account.new
  account.name = 'John Doe'
  account.currency = 'USD'
  account.create(user, reason, comment, options)
end

def get_kb_account(account_id, options)
  KillBillClient::Model::Account.find_by_id(account_id, false, false, options)
end

# Credit card auth creating a recurring contract
def auth(account, encrypted_json, user, reason, comment, options)
  # Adyen contract
  contract_prop = KillBillClient::Model::PluginPropertyAttributes.new
  contract_prop.key = 'recurringType'
  contract_prop.value = 'RECURRING'

  # Adyen encrypted card data and timestamp
  ee_prop = KillBillClient::Model::PluginPropertyAttributes.new
  ee_prop.key = 'encryptedJson'
  ee_prop.value = encrypted_json

  transaction = KillBillClient::Model::Transaction.new
  transaction.amount = 1
  transaction.currency = 'USD'
  transaction.auth(account.account_id, nil, user, reason, comment, options.dup.merge({:pluginProperty => [contract_prop, ee_prop]}))
end

def void(payment, user, reason, comment, options)
  transaction = KillBillClient::Model::Transaction.new
  transaction.payment_id = payment.payment_id
  transaction.void(user, reason, comment, options)
end

# HPP directory lookup
def directory_lookup(account, user, reason, comment, options)
  hpp = KillBillClient::Model::HostedPaymentPage.new
  hpp.form_fields = []

  {
      :amount => 10,
      :currency => 'USD',
      :lookupDirectory => true
  }.each do |key, value|
    field = KillBillClient::Model::PluginPropertyAttributes.new
    field.key = key.to_s
    field.value = value
    hpp.form_fields << field
  end

  descriptor = hpp.build_form_descriptor(account.account_id, nil, user, reason, comment, options)
  (descriptor.form_fields['directory'] || {})['paymentMethods'] || {}
end

# HPP redirect url builder
def build_form_descriptor(account, invoice, brand_code, user, reason, comment, options)
  hpp = KillBillClient::Model::HostedPaymentPage.new
  hpp.form_fields = []

  {
      :amount => 10,
      :currency => 'USD',
      :brandCode => brand_code,
      :serverUrl => "http://#{settings.bind}:#{settings.port}",
      :resultUrl => "/charge/complete?kbAccountId=#{account.account_id}&kbInvoiceId=#{invoice.invoice_id}"
  }.each do |key, value|
    field = KillBillClient::Model::PluginPropertyAttributes.new
    field.key = key.to_s
    field.value = value
    hpp.form_fields << field
  end

  descriptor = hpp.build_form_descriptor(account.account_id, nil, user, reason, comment, options)
  descriptor.form_url + '?' + descriptor.form_fields.map { |k, v| [CGI.escape(k.to_s), '=', CGI.escape(v.to_s)] }.map(&:join).join('&')
end

# Record a payment post HPP redirect
def pay_invoice(account_id, invoice_id, adyen_params, user, reason, comment, options)
  params = adyen_params.dup.merge({:fromHPP => true})

  props = []
  params.each do |key, value|
    field = KillBillClient::Model::PluginPropertyAttributes.new
    field.key = key.to_s
    field.value = value
    props << field
  end

  payment = KillBillClient::Model::InvoicePayment.new
  payment.account_id = account_id
  payment.target_invoice_id = invoice_id
  payment.purchased_amount = 10
  payment.create(payment, user, reason, comment, options.dup.merge({:pluginProperty => props}))
end

# Create an empty payment method
def create_kb_payment_method(account, user, reason, comment, options)
  pm = KillBillClient::Model::PaymentMethod.new
  pm.account_id = account.account_id
  pm.plugin_name = 'killbill-adyen'
  pm.plugin_info = {}
  pm.create(true, user, reason, comment, options)
end

def sync_recurring_contract(account, encrypted_json, user, reason, comment, options)
  # $1 verification (auth/void): Adyen requires a payment to tokenize the card
  payment = auth(account, encrypted_json, user, reason, comment, options)
  void(payment, user, reason, comment, options)

  # Sync the payment methods to get the freshly created Adyen token
  KillBillClient::Model::PaymentMethod.refresh(account.account_id, user, reason, comment, options)
end

def create_subscription(account, should_wait_for_payment, user, reason, comment, options)
  subscription = KillBillClient::Model::Subscription.new
  subscription.account_id = account.account_id
  subscription.product_name = 'Sports'
  subscription.product_category = 'BASE'
  subscription.billing_period = 'MONTHLY'
  subscription.price_list = 'DEFAULT'
  subscription.price_overrides = []

  # For the demo to be interesting, override the trial price to be non-zero so we trigger a charge in Adyen
  override_trial = KillBillClient::Model::PhasePriceOverrideAttributes.new
  override_trial.phase_type = 'TRIAL'
  override_trial.fixed_price = 10.0
  subscription.price_overrides << override_trial

  subscription.create(user, reason, comment, nil, should_wait_for_payment, options)
end

#
# Sinatra handlers
#

get '/' do
  # Create an account
  @account = create_kb_account(user, reason, comment, options)

  # Add a payment method
  create_kb_payment_method(@account, user, reason, comment, options)

  # Look-up available payment methods
  @directory = directory_lookup(@account, user, reason, comment, options)

  erb :index
end

post '/charge' do
  account = get_kb_account(params['kb-account-id'], options)

  encrypted_cc = params['adyen-encrypted-data']
  is_manual_pay = encrypted_cc.nil?
  if is_manual_pay
    # Tell Kill Bill not to attempt to auto-pay the invoices
    account.set_manual_pay(user, reason, comment, options)
  else
    sync_recurring_contract(account, encrypted_cc, user, reason, comment, options)
  end

  # Add a subscription
  create_subscription(account, !is_manual_pay, user, reason, comment, options)

  # Retrieve the invoice
  @invoice = account.invoices(true, options).first

  if is_manual_pay
    brand_code = nil
    params.each_key do |k|
      brand_code = k.split('brand-')[1]
      break unless brand_code.nil?
    end
    skin_url = build_form_descriptor(account, @invoice, brand_code, user, reason, comment, options)
    redirect to(skin_url)
  else
    # And the Adyen reference
    transaction = @invoice.payments(false, true, 'NONE', options).first.transactions.first
    @authorization = transaction.first_payment_reference_id

    erb :charge
  end
end

get '/charge/complete' do
  # Record the payment for that invoice
  account_id = params.delete('kbAccountId')
  invoice_id = params.delete('kbInvoiceId')
  pay_invoice(account_id, invoice_id, params, user, reason, comment, options)

  # Retrieve the invoice
  @invoice = KillBillClient::Model::Invoice.find_by_id_or_number(invoice_id, true, 'NONE', options)

  # And the Adyen reference
  transaction = @invoice.payments(false, true, 'NONE', options).first.transactions.first
  @authorization = transaction.first_payment_reference_id

  erb :charge
end

__END__

@@ layout
  <!DOCTYPE html>
  <html>
  <head></head>
  <body>
    <%= yield %>
  </body>
  </html>

@@index
  <span class="image"><img src="https://drive.google.com/uc?&amp;id=0Bw8rymjWckBHT3dKd0U3a1RfcUE&amp;w=960&amp;h=480" alt="uc?&amp;id=0Bw8rymjWckBHT3dKd0U3a1RfcUE&amp;w=960&amp;h=480"></span>
  <form action="/charge" method="post" id="adyen-encrypted-form">
    <article>
      <label class="amount">
        <span>Sports car, 30 days trial for only $10.00!</span>
      </label>
    </article>
    <input type="hidden" value="<%= @account.account_id %>" name="kb-account-id" />
    <br/>
    <div><label><span>Card Number</span>&nbsp;<input type="text" size="20" data-encrypted-name="number" /></label></div>
    <div><label><span>Name</span>&nbsp;<input type="text" size="20" data-encrypted-name="holderName" /></label></div>
    <div><label><span>Expiration (MM/YYYY)</span>&nbsp;<input type="text" size="2" maxlength="2" data-encrypted-name="expiryMonth" />/<input type="text" size="4" maxlength="4" data-encrypted-name="expiryYear" /></label></div>
    <div><label><span>CVC</span>&nbsp;<input type="text" size="4" maxlength="4" data-encrypted-name="cvc" /></label></div>
    <input type="hidden" value="<%= Time.now.iso8601 %>" data-encrypted-name="generationtime" />
    <input type="submit" name="cc" value="Pay" />
  </form>
  <br/>
  <form action="/charge" method="post">
    <input type="hidden" value="<%= @account.account_id %>" name="kb-account-id" />
    Or pay via <input type="submit" name="hpp" value="HPP" />
  </form>
  <br/>
  Or pay via these payment methods directly:
  <ul>
    <% @directory.each do |pm| %>
      <li>
        <form action="/charge" method="post">
          <input type="hidden" value="<%= @account.account_id %>" name="kb-account-id" />
          <input type="submit" name="brand-<%= pm['brandCode'] %>" value="<%= pm['name'] %>" />
        </form>
      </li>
    <% end %>
  </ul>
  <script src="https://test.adyen.com/hpp/cse/js/<%= settings.encryption_token %>.shtml"></script>
  <script>
    var form    = document.getElementById('adyen-encrypted-form');
    var options = {};
    adyen.createEncryptedForm(form, options);
  </script>

@@charge
  <h2>Thanks! Here is your invoice:</h2>
  <% unless @invoice.nil? %>
    <ul>
      <% @invoice.items.each do |item| %>
        <li><%= "subscription_id=#{item.subscription_id}, amount=#{item.amount}, phase=sports-monthly-trial, start_date=#{item.start_date}" %></li>
      <% end %>
    </ul>
  <% end %>
  You can verify the payment at <a href="<%= "https://ca-test.adyen.com/ca/ca/accounts/showTx.shtml?txType=Payment&pspReference=#{@authorization}" %>"><%= "https://ca-test.adyen.com/ca/ca/accounts/showTx.shtml?txType=Payment&pspReference=#{@authorization}" %></a>.
