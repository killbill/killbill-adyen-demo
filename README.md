Kill Bill Adyen demo
=====================

Inspired from the Adyen Drop-In implemantation [Here](https://docs.adyen.com/online-payments/web-drop-in) 

Prerequisites
-------------

* Kill Bill is [already setup](https://docs.killbill.io/latest/getting_started.html)
* The default tenant (bob/lazar) has been created
* The Adyen plugin is installed and configured

Set up
------

Go to the application.property and change the information of the fields that need to be changed 


Run
---

To run the app:
```
mvn spring-boot:run
```

Test 
----

Go to [http://localhost:8086/](http://localhost:8086/) where you should see a box where the amount of the payment need to be input.

After that a drop-in will show up 