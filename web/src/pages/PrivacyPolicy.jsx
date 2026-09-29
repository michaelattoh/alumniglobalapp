import Footer from "../components/Footer";

const sections = [
  {
    title: "Information We Collect",
    body:
      "We collect account details you provide to us such as your name, email address, institution, profile information, and content you publish in the app or website. We also collect activity data needed to support networking, messaging, event participation, donations, notifications, and account security.",
  },
  {
    title: "How We Use Information",
    body:
      "We use your information to create and manage your account, connect you with alumni and institutions, deliver messages and notifications, process payments and donations, improve recommendations, secure the platform, and provide customer support.",
  },
  {
    title: "Messages, Content, and Media",
    body:
      "Posts, stories, profile details, media uploads, and messages are processed to provide the platform features you use. Content you mark as public may be visible to other users as intended by the feature. Private or restricted content is handled according to your visibility settings and platform permissions.",
  },
  {
    title: "Notifications and Communications",
    body:
      "We may send in-app notifications, push notifications, emails, and service communications related to account activity, connection requests, messages, events, donations, verification, and important platform updates. You can adjust notification preferences in supported areas of the platform.",
  },
  {
    title: "Payments and Transactions",
    body:
      "When payments or donations are processed, payment information is handled through supported third-party payment providers. Alumni Global Network does not store full card details on its application servers. Transaction-related data may be stored for receipts, verification, reporting, compliance, and dispute handling.",
  },
  {
    title: "Analytics and Security",
    body:
      "We use technical logs, device information, and analytics data to maintain performance, prevent abuse, detect fraud, troubleshoot issues, and improve the quality and safety of the platform.",
  },
  {
    title: "Sharing of Information",
    body:
      "We may share limited information with service providers that support hosting, email delivery, notifications, analytics, authentication, file storage, and payment processing. We may also disclose information where required by law, to enforce platform rules, or to protect users and the platform.",
  },
  {
    title: "Data Retention",
    body:
      "We retain information for as long as needed to operate the platform, comply with legal obligations, resolve disputes, enforce agreements, and maintain security and audit records. Retention periods may vary depending on the feature and legal requirements involved.",
  },
  {
    title: "Your Choices",
    body:
      "You may update parts of your profile information, manage certain notification settings, and contact us regarding account support or data concerns. Some information may remain in backups, logs, or compliance records where legally required.",
  },
  {
    title: "Contact",
    body:
      "If you have questions about this privacy policy or how your information is handled, contact Alumni Global Network support at support@alumniglobalnetwork.com.",
  },
];

function PrivacyPolicy() {
  return (
    <div className="privacy-page">
      <header className="privacy-hero">
        <div className="privacy-shell">
          <a className="privacy-back" href="/">
            Back to website
          </a>
          <div className="privacy-kicker">Privacy Policy</div>
          <h1>How Alumni Global Network handles personal information</h1>
          <p>
            This policy explains what information we collect, how we use it, and how the
            platform supports communication, community, payments, and account security.
          </p>
          <div className="privacy-meta">Last updated: March 11, 2026</div>
        </div>
      </header>

      <main className="privacy-main">
        <div className="privacy-shell privacy-layout">
          <aside className="privacy-toc">
            <div className="privacy-toc-card">
              <div className="privacy-toc-title">Sections</div>
              {sections.map((section) => (
                <a key={section.title} href={`#${section.title.toLowerCase().replaceAll(" ", "-")}`}>
                  {section.title}
                </a>
              ))}
            </div>
          </aside>

          <section className="privacy-content">
            {sections.map((section) => (
              <article
                key={section.title}
                id={section.title.toLowerCase().replaceAll(" ", "-")}
                className="privacy-card"
              >
                <h2>{section.title}</h2>
                <p>{section.body}</p>
              </article>
            ))}
          </section>
        </div>
      </main>

      <Footer />
    </div>
  );
}

export default PrivacyPolicy;
