export default function PrivacyPolicy() {
  return (
    <main className="policy">
      <div className="policy-card">
        <h1>Privacy Policy</h1>
        <p className="updated">Last updated: October 1, 2026</p>

        <p>
          This Privacy Policy describes how <strong>Bamas Burger Box</strong>{' '}
          ("we", "us", or "our") collects, uses, and shares information when
          you use our mobile application (the "App"). By using the App, you
          agree to the collection and use of information in accordance with
          this policy.
        </p>

        <h2>1. Information We Collect</h2>
        <p>We may collect the following types of information:</p>
        <ul>
          <li>
            <strong>Account information:</strong> your name, phone number,
            and email address when you create an account or sign in.
          </li>
          <li>
            <strong>Order information:</strong> delivery address, order
            history, and items you purchase through the App.
          </li>
          <li>
            <strong>Device and usage information:</strong> device type,
            operating system, app version, and usage analytics collected
            through Firebase Analytics, to help us understand how the App is
            used and to improve it.
          </li>
          <li>
            <strong>Push notification data:</strong> a device token used to
            send you order updates and offers, if you allow notifications.
          </li>
        </ul>
        <p>
          We do <strong>not</strong> collect or store your payment card
          details. Payments, where applicable, are handled through secure
          third-party payment processors.
        </p>

        <h2>2. How We Use Your Information</h2>
        <ul>
          <li>To process and deliver your orders</li>
          <li>To communicate with you about your orders and account</li>
          <li>To send order updates, offers, and notifications (optional)</li>
          <li>To improve the App's features, performance, and reliability</li>
          <li>To prevent fraud and keep the App secure</li>
        </ul>

        <h2>3. Sharing of Information</h2>
        <p>
          We do not sell your personal information. We may share information
          with:
        </p>
        <ul>
          <li>
            Service providers that help us operate the App, such as Firebase
            (Google) for authentication, data storage, analytics, and push
            notifications.
          </li>
          <li>Delivery personnel, solely to complete your order delivery.</li>
          <li>
            Authorities, where required by law or to protect our legal
            rights.
          </li>
        </ul>

        <h2>4. Data Storage and Security</h2>
        <p>
          Your information is stored securely using industry-standard
          services (including Google Firebase). We take reasonable measures
          to protect your information from unauthorized access, alteration,
          or disclosure.
        </p>

        <h2>5. Your Choices</h2>
        <ul>
          <li>You can update your account information within the App.</li>
          <li>
            You can disable push notifications at any time from your device
            settings.
          </li>
          <li>
            You can request deletion of your account and associated data by
            contacting us using the details below.
          </li>
        </ul>

        <h2>6. Children's Privacy</h2>
        <p>
          The App is not directed at children under 13, and we do not
          knowingly collect personal information from children under 13.
        </p>

        <h2>7. Changes to This Policy</h2>
        <p>
          We may update this Privacy Policy from time to time. Any changes
          will be posted on this page with an updated "Last updated" date.
        </p>

        <h2>8. Contact Us</h2>
        <p>
          If you have any questions about this Privacy Policy or your data,
          please contact us at:
        </p>
        <p className="contact">
          Email:{' '}
          <a href="mailto:bamasplaystore@gmail.com">
            bamasplaystore@gmail.com
          </a>
        </p>
      </div>
    </main>
  )
}
