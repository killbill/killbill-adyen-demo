Kill Bill Adyen demo
=====================

Inspired from the [Adyen Drop-In implementation](https://docs.adyen.com/online-payments/web-drop-in).

Prerequisites
-------------

* Kill Bill is [already setup](https://docs.killbill.io/latest/getting_started.html)
* The default tenant (bob/lazar) has been created
* The [Adyen plugin](https://github.com/killbill/killbill-adyen-plugin) is installed and configured

Set up
------

Update  `application.properties` with your Adyen credentials.


Run
---

To run the app:
```
mvn spring-boot:run
```

Test 
----

Go to [http://localhost:8084/](http://localhost:8084/) where you should see a box where the amount of the payment need to be input.

After that a drop-in will show up.