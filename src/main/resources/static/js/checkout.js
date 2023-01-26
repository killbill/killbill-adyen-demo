$(document).ready(function() {
	let selectedAmount = 0;
	let checkout = async function(result) {
		const configuration = {
			environment: 'test', // Change to 'live' for the live environment.
			clientKey: $("#clientKey").val(), // Public key used for client-side authentication: https://docs.adyen.com/development-resources/client-side-authentication
			session: {
				id: result.id, // Unique identifier for the payment session.
				sessionData: result.sessionData // The payment session data.
			},
			onPaymentCompleted: (result, component) => {
				
				console.info("paymentData",result, component);
				$("#pleaseRefresh").show();
			},
			onError: (error, component) => {
				console.error(error.name, error.message, error.stack, component);
			},
			// Any payment method specific configuration. Find the configuration specific to each payment method:  https://docs.adyen.com/payment-methods
			// For example, this is 3D Secure configuration for cards:
			paymentMethodsConfiguration: {
				card: {
					hasHolderName: true,
					holderNameRequired: true,
					name: "Credit or debit card",
					amount: {
						value: String (selectedAmount).replace(".", "") ,
						currency: "USD",
					}
				}
			} 
		};

		// Create an instance of AdyenCheckout using the configuration object.
		const checkout = await AdyenCheckout(configuration);
	
		$("#checkout").hide();
		// Create an instance of Drop-in and mount it to the container you created.
		//checkout.create('dropin').mount('#dropin-container');
		checkout.create('dropin').mount(document.getElementById("dropin-container"));
	};

	$("#checkoutClick").on("click", function(event) {
		$("#checkoutClick").hide();
		$("#spinner").show();
		selectedAmount = $("#amountToPaid").val();
		let checkBox = $("#myCheck").is(":checked");
		$.ajax({
			url: "/api/session?amount=" + selectedAmount  +"&isRecurring="+checkBox,
			success: function(result) {
				console.log("wawa", result);
				checkout(result);
			}
		});
	});
});

