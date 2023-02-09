package org.killbill.billing.plugin.payment.adyen.demo;

import java.math.BigDecimal;
import java.util.HashMap;
import java.util.Map;
import org.killbill.billing.client.KillBillClientException;
import org.killbill.billing.client.model.gen.Account;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
public class ApiController {

  @Autowired ClientService clientService;

  @GetMapping("/session")
  public SessionModel getSession(
      @RequestParam(name = "amount") BigDecimal amount,
      @RequestParam(name = "isRecurring") Boolean isRecurring)
      throws KillBillClientException {
    if (isRecurring == null) {
      isRecurring = false;
    }

    Account account = clientService.createKBAccount();
    if (amount == null) {
      amount = BigDecimal.TEN;
    }
    Map<String, String> prop = new HashMap<>();
    prop.put(ClientService.NEW_SESSION_AMOUNT, amount.toPlainString());
    prop.put(ClientService.ENABLE_RECURRING, isRecurring.toString());
    return clientService.createSession(account, prop);
  }
}
