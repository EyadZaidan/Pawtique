const functions = require('firebase-functions');
const admin = require('firebase-admin');
const emailjs = require('@emailjs/nodejs');
const crypto = require('crypto');

admin.initializeApp();

emailjs.init("VXgp94DZXU0uolLjz");

exports.sendVerificationEmail = functions.firestore
  .document('users/{userId}')
  .onCreate(async (snap, context) => {
    const userData = snap.data();
    const email = userData.email;
    const fullName = userData.fullName;
    const userId = context.params.userId;

    if (!email || !fullName) {
      console.error("Missing email or fullName in user data.");
      return null;
    }

    const token = crypto.randomBytes(32).toString('hex');
    const verificationLink = `https://pawtique3.page.link/verify?token=${token}&uid=${userId}`;

    // Save token to Firestore
    await admin.firestore().collection('users').doc(userId).update({
      verificationToken: token,
    });

    const templateParams = {
      to_email: email,
      to_name: fullName,
      verification_link: verificationLink,
    };

    try {
      await emailjs.send("service_xjfv928", "template_v761fvr", templateParams, {
        publicKey: "VXgp94DZXU0uolLjz",
      });

      console.log(`Verification email sent to ${email}`);
    } catch (error) {
      console.error("Error sending email:", error);
    }

    return null;
  });
