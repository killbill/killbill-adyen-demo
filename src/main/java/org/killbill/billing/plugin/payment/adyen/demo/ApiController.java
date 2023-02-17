/*
 * Copyright 2020-2023 Equinix, Inc
 * Copyright 2014-2023 The Billing Project, LLC
 *
 * Ning licenses this file to you under the Apache License, version 2.0
 * (the "License"); you may not use this file except in compliance with the
 * License.  You may obtain a copy of the License at:
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
 * License for the specific language governing permissions and limitations
 * under the License.
 */
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

    @Autowired
    ClientService clientService;

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
