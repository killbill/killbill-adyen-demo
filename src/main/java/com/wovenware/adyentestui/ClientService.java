package com.wovenware.adyentestui;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import javax.annotation.PostConstruct;
import org.joda.time.LocalDate;
import org.killbill.billing.catalog.api.Currency;
import org.killbill.billing.client.KillBillClientException;
import org.killbill.billing.client.KillBillHttpClient;
import org.killbill.billing.client.RequestOptions;
import org.killbill.billing.client.RequestOptions.RequestOptionsBuilder;
import org.killbill.billing.client.api.gen.AccountApi;
import org.killbill.billing.client.api.gen.InvoiceApi;
import org.killbill.billing.client.api.gen.SubscriptionApi;
import org.killbill.billing.client.model.Invoices;
import org.killbill.billing.client.model.gen.Account;
import org.killbill.billing.client.model.gen.InvoicePayment;
import org.killbill.billing.client.model.gen.PaymentMethod;
import org.killbill.billing.client.model.gen.PluginProperty;
import org.killbill.billing.client.model.gen.Subscription;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

@Service
public class ClientService {

  @Value("${killbill.client.url}")
  private String killbillClientUrl;

  @Value("${killbill.client.disable-ssl-verification}")
  private String killbillClientDisableSSL;

  @Value("${killbill.username}")
  private String username;

  @Value("${killbill.password}")
  private String password;

  @Value("${killbill.api-key}")
  private String apiKey;

  @Value("${killbill.api-secret}")
  private String apiSecret;

  @Value("${plugin.name}")
  private String pluginName;

  @Value("${checkoutUrl}")
  private String checkoutUrl;

  private AccountApi accountApi;
  private SubscriptionApi subscriptionApi;
  private InvoiceApi invoiceApi;
  private KillBillHttpClient httpClient;
  private RestTemplate restTemplate = new RestTemplate();

  // KEYS
  private static final String SESSION_DATA = "sessionData";
  private static final String SESSION_ID = "sessionId";

  public static final String NEW_SESSION_AMOUNT = "amount";
  public static final String PAYMENT_METHOD_ID = "paymentMethodId";
  public static final String ENABLE_RECURRING = "enableRecurring";
  private static final String KB_ACCOUNT_ID = "kbAccountId";

  @PostConstruct
  public void init() {
    httpClient = new KillBillHttpClient(killbillClientUrl, username, password, apiKey, apiSecret);
    accountApi = new AccountApi(httpClient);
    subscriptionApi = new SubscriptionApi(httpClient);
    invoiceApi = new InvoiceApi(httpClient);
  }

  private RequestOptions getOptions() {
    RequestOptionsBuilder builder = new RequestOptionsBuilder();
    builder.withComment("Trigget by test").withCreatedBy("admin").withReason("JAJA");

    return builder.build();
  }

  /**
   * @return
   * @throws KillBillClientException
   */
  public Account createKBAccount() throws KillBillClientException {
    Account body = new Account();
    body.setCurrency(Currency.USD);
    body.setEmail("john@laposte.com");
    body.setName("John Doe");
    return accountApi.createAccount(body, getOptions());
  }

  /**
   * @param account
   * @param sessionId
   * @param token
   * @return
   * @throws KillBillClientException
   */
  public PaymentMethod createKBPaymentMethod(Account account, Map<String, String> pluginOptions)
      throws KillBillClientException {
    PaymentMethod pm = new PaymentMethod();
    pm.setAccountId(account.getAccountId());
    pm.setPluginName(pluginName);

    return accountApi.createPaymentMethod(
        account.getAccountId(), pm, null, pluginOptions, getOptions());
  }

  /**
   * @param account
   * @return
   * @throws KillBillClientException
   */
  public Subscription createSubscription(Account account) throws KillBillClientException {

    Subscription input = new Subscription();
    input.setAccountId(account.getAccountId());
    input.setExternalKey("somethingSpecial");
    input.setPlanName("shotgun-monthly");

    LocalDate entitlementDate = null;
    LocalDate billingDate = null;

    return subscriptionApi.createSubscription(
        input, entitlementDate, billingDate, null, getOptions());
  }

  /**
   * @param account
   * @param pluginOptions
   * @throws KillBillClientException
   */
  public SessionModel createSession(Account account, Map<String, String> pluginOptions)
      throws KillBillClientException {
    Map<String, String> paymentMethodProp = new HashMap<>();
    paymentMethodProp.put(ENABLE_RECURRING, pluginOptions.get(ENABLE_RECURRING));
    PaymentMethod paymentMethod = createKBPaymentMethod(account, paymentMethodProp);

    pluginOptions.put(PAYMENT_METHOD_ID, paymentMethod.getPaymentMethodId().toString());
    List<PluginProperty> formFields = new ArrayList<>();
    pluginOptions.forEach(
        (key, value) -> {
          formFields.add(new PluginProperty(key, value, false));
        });
    pluginOptions.put(KB_ACCOUNT_ID, account.getAccountId().toString());
    HttpEntity<List<PluginProperty>> request =
        new HttpEntity<List<PluginProperty>>(formFields, getHeaders());
    String resourceUrl =
        checkoutUrl
            + "/checkout?kbAccountId={kbAccountId}&amount={amount}&kbPaymentMethodId={paymentMethodId}";
    Map<String, String> test =
        restTemplate.postForObject(resourceUrl, request, HashMap.class, pluginOptions);

    String sessionData = test.get(SESSION_DATA);
    String sessionId = test.get(SESSION_ID);

    SessionModel sessionModel = new SessionModel();
    sessionModel.setId(sessionId);
    sessionModel.setSessionData(sessionData);
    return sessionModel;
  }

  /**
   * @param accountId
   * @param sessionId
   * @param token
   * @throws KillBillClientException
   */
  public void charge(String accountId, String sessionId, String token)
      throws KillBillClientException {
    Account account = accountApi.getAccount(UUID.fromString(accountId), getOptions());

    // # Add a subscription
    createSubscription(account);

    // # Retrieve the invoice
    Invoices invoice =
        accountApi.getInvoicesForAccount(account.getAccountId(), null, null, null, getOptions());
    UUID lastInvoiceId = invoice.get(invoice.size() - 1).getInvoiceId();
    InvoicePayment invoicePayment = new InvoicePayment();
    invoicePayment.setPurchasedAmount(BigDecimal.TEN);
    invoicePayment.setAccountId(UUID.fromString(accountId));
    invoicePayment.setTargetInvoiceId(lastInvoiceId);
    // Trigger payment
    this.invoiceApi.createInstantPayment(
        invoice.get(invoice.size() - 1).getInvoiceId(), invoicePayment, null, null, getOptions());
  }

  public HttpHeaders getHeaders() {
    HttpHeaders headers = new HttpHeaders();
    headers.add("X-Killbill-ApiKey", apiKey);
    headers.add("X-Killbill-ApiSecret", apiSecret);
    headers.add("X-Killbill-CreatedBy", "test");
    headers.setContentType(MediaType.APPLICATION_JSON);
    headers.setBasicAuth(username, password);
    return headers;
  }
}
