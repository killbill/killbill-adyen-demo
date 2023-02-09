package org.killbill.billing.plugin.payment.adyen.demo;

import lombok.Getter;
import lombok.Setter;

@Setter
@Getter
public class SessionModel {

  String id;
  String sessionData;

  public String getId() {
    return id;
  }

  public void setId(String id) {
    this.id = id;
  }

  public String getSessionData() {
    return sessionData;
  }

  public void setSessionData(String sessionData) {
    this.sessionData = sessionData;
  }
}
