package org.killbill.billing.plugin.payment.adyen.demo;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.RequestMapping;

@Controller
public class ViewController {
  @Value("${adyen.test.clientKey}")
  private String clientKey;

  @RequestMapping(value = "/")
  public String index(Model model) {
    model.addAttribute("clientKey", clientKey);
    return "index";
  }
}
