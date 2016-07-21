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
  transaction.auth(account.account_id, nil, user, reason, comment, options.dup.merge( {:pluginProperty => [ contract_prop, ee_prop ]} ))
end

def void(payment, user, reason, comment, options)
  transaction = KillBillClient::Model::Transaction.new
  transaction.payment_id = payment.payment_id
  transaction.void(user, reason, comment, options)
end

def create_kb_payment_method(account, encrypted_json, user, reason, comment, options)
  # Create an empty payment method (Adyen requires a payment to tokenize the card)
  pm = KillBillClient::Model::PaymentMethod.new
  pm.account_id = account.account_id
  pm.plugin_name = 'killbill-adyen'
  pm.plugin_info = {}
  pm.create(true, user, reason, comment, options)

  # $1 verification (auth/void)
  payment = auth(account, encrypted_json, user, reason, comment, options)
  void(payment, user, reason, comment, options)

  # Sync the payment methods to get the freshly created Adyen token
  KillBillClient::Model::PaymentMethod.refresh(account.account_id, user, reason, comment, options)
end

def create_subscription(account, user, reason, comment, options)
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

  subscription.create(user, reason, comment, nil, true, options)
end

#
# Sinatra handlers
#

get '/' do
  erb :index
end

post '/charge' do
  # Create an account
  account = create_kb_account(user, reason, comment, options)

  # Add a payment method
  create_kb_payment_method(account, params['adyen-encrypted-data'], user, reason, comment, options)

  # Add a subscription
  create_subscription(account, user, reason, comment, options)

  # Retrieve the invoice
  @invoice = account.invoices(true, options).first

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
    <br/>
    <div><label><span>Card Number</span>&nbsp;<input type="text" size="20" data-encrypted-name="number" /></label></div>
    <div><label><span>Name</span>&nbsp;<input type="text" size="20" data-encrypted-name="holderName" /></label></div>
    <div><label><span>Expiration (MM/YYYY)</span>&nbsp;<input type="text" size="2" maxlength="2" data-encrypted-name="expiryMonth" />/<input type="text" size="4" maxlength="4" data-encrypted-name="expiryYear" /></label></div>
    <div><label><span>CVC</span>&nbsp;<input type="text" size="4" maxlength="4" data-encrypted-name="cvc" /></label></div>
    <input type="hidden" value="<%= Time.now.iso8601 %>" data-encrypted-name="generationtime" />
    <input type="submit" value="Pay" />
    <script src="https://test.adyen.com/hpp/cse/js/<%= settings.encryption_token %>.shtml"></script>
    <script>
      var form    = document.getElementById('adyen-encrypted-form');
      var options = {};

      adyen.createEncryptedForm(form, options);
    </script>
  </form>

@@charge
  <h2>Thanks! Here is your invoice:</h2>
  <ul>
    <% @invoice.items.each do |item| %>
      <li><%= "subscription_id=#{item.subscription_id}, amount=#{item.amount}, phase=sports-monthly-trial, start_date=#{item.start_date}" %></li>
    <% end %>
  </ul>
  You can verify the payment at <a href="<%= "https://ca-test.adyen.com/ca/ca/accounts/showTx.shtml?txType=Payment&pspReference=#{@authorization}" %>"><%= "https://ca-test.adyen.com/ca/ca/accounts/showTx.shtml?txType=Payment&pspReference=#{@authorization}" %></a>.
