const functions = require('firebase-functions');
const nodemailer = require('nodemailer');

const admin = require('firebase-admin');
admin.initializeApp();

const transporter = nodemailer.createTransport({
  service: functions.config().email.service,
  auth: {
    user: functions.config().email.user,
    pass: functions.config().email.pass,
  },
});

exports.sendOrderConfirmationEmail = functions.firestore
  .document('orders/{orderId}')
  .onCreate(async (snap, context) => {
    const order = snap.data();
    const orderId = context.params.orderId;

    console.log('New order created:', order);

    const confirmationNumber = order.confirmationNumber || 'N/A';
    const userEmail = order.email;
    const items = order.items || [];
    const totalPrice = order.totalPrice || 0;
    const name = order.name || 'Customer';
    const shippingAddress = order.shippingAddress || 'N/A';
    const paymentMethod = order.paymentMethod || 'N/A';
    const timestamp = order.timestamp ? order.timestamp.toDate().toLocaleString() : new Date().toLocaleString();

    if (!userEmail) {
      console.error('Error: Email field is missing in order document:', orderId);
      throw new functions.https.HttpsError('invalid-argument', 'Email field is required');
    }

    const itemsListText = items.length > 0
      ? items.map(item => `${item.name} - Quantity: ${item.quantity} - Price: $${item.price.toFixed(2)}`).join('\n')
      : 'No items found';
    const itemsListHtml = items.length > 0
      ? items.map(item => `<li>${item.name} - Quantity: ${item.quantity} - Price: $${item.price.toFixed(2)}</li>`).join('')
      : '<li>No items found</li>';

    const mailOptions = {
      from: functions.config().email.user,
      to: userEmail,
      subject: `Order Confirmation - ${confirmationNumber}`,
      text: `
        Dear ${name},

        Thank you for your order with Pawtique3! Below are the details of your purchase:

        Order Confirmation Number: ${confirmationNumber}
        Order Date: ${timestamp}
        Items:
        ${itemsListText}
        Total Price: $${totalPrice.toFixed(2)}
        Shipping Address: ${shippingAddress}
        Payment Method: ${paymentMethod}

        We will notify you once your order has shipped.

        Best regards,
        The Pawtique3 Team
      `,
      html: `
        <h2>Order Confirmation - ${confirmationNumber}</h2>
        <p>Dear ${name},</p>
        <p>Thank you for your order with Pawtique3! Below are the details of your purchase:</p>
        <ul>
          <li><strong>Order Confirmation Number:</strong> ${confirmationNumber}</li>
          <li><strong>Order Date:</strong> ${timestamp}</li>
          <li><strong>Items:</strong>
            <ul>
              ${itemsListHtml}
            </ul>
          </li>
          <li><strong>Total Price:</strong> $${totalPrice.toFixed(2)}</li>
          <li><strong>Shipping Address:</strong> ${shippingAddress}</li>
          <li><strong>Payment Method:</strong> ${paymentMethod}</li>
        </ul>
        <p>We will notify you once your order has shipped.</p>
        <p>Best regards,<br>The Pawtique3 Team</p>
      `,
    };

    try {
      await transporter.sendMail(mailOptions);
      console.log(`Email sent to ${userEmail} for order ${confirmationNumber}`);
      return null;
    } catch (error) {
      console.error(`Error sending email for order ${confirmationNumber}:`, error);
      throw new functions.https.HttpsError('internal', 'Failed to send email');
    }
  });