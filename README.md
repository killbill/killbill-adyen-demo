Kill Bill Adyen demo
====================

This sample app shows you how to integrate Adyen with [Kill Bill subscriptions APIs](http://docs.killbill.io/0.16/userguide_subscription.html).

Prerequisites
-------------

Ruby 2.1+ or JRuby 1.7.20+ is recommended. If you don’t have a Ruby installation yet, use [RVM](https://rvm.io/rvm/install):

```
gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
\curl -sSL https://get.rvm.io | bash -s stable --ruby
```

After following the post-installation instructions, you should have access to the ruby and gem executables.

Install the dependencies by running in this folder:

```
gem install bundler
bundle install
```

This also assumes Kill Bill is [running locally](http://docs.killbill.io/0.16/getting_started.html) at 127.0.0.1:8080 with the [Adyen plugin](https://github.com/killbill/killbill-adyen-plugin) configured.

Run
---

To run the app:

```
ENCRYPTION_TOKEN=<YOUR_ENCRYPTION_TOKEN> ruby app.rb
```

then go to [http://localhost:4567/](http://localhost:4567/) where you should see the checkout form.

### Easy Encryption

Enter dummy data (4111111111111111 as the credit card number, 737 as the CVC and 08/2018 as the expiry date) and complete the checkout process.

This will:

* Create a recurring contract for the card in Adyen
* Create a new Kill Bill account
* Add a default payment method on this account associated with this contract
* Create a new subscription for the sports car monthly plan (with a $10 30-days trial)
* Charge the card for $10

### HPP

Go to the Hosted Payment Page (HPP) to complete the checkout process.

This will:

* Create a new Kill Bill account
* Set the account in manual pay mode (i.e. recurring payments are not possible)
* Add a default payment method on this account
* Create a new subscription for the sports car monthly plan (with a $10 30-days trial)
* Redirect the user to Adyen
* Upon redirection from Adyen, record the $10 payment against the generated invoice

Note: the types of payment methods available on Adyen's HPP depend on your configured skins.
