import "../styles/contact.css";

import appstore from "../assets/images/appstore.png";
import playstore from "../assets/images/playstore.png";

const APPLE_STORE_URL =
  "https://apps.apple.com/app/global-alumni-network/id6759199673";
const PLAY_STORE_URL =
  "https://play.google.com/store/apps/details?id=com.alumniglobalnetwork.app";

export default function Contact() {
  return (
    <section className="contact-section"id="contact">

      <div className="contact-bg"></div>

      <div className="contact-container">

        <h2 className="contact-title">
          <span className="gradient-text">Download Now</span>
        </h2>

        <p className="contact-subtitle">
          Get instant access to the alumni network, opportunities, and tools
          designed to help you grow faster and connect globally.
        </p>

        <div className="store-buttons">

          <a
            href={APPLE_STORE_URL}
            target="_blank"
            rel="noopener noreferrer"
          >
            <img src={appstore} alt="Download on App Store" />
          </a>

          <a
            href={PLAY_STORE_URL}
            target="_blank"
            rel="noopener noreferrer"
          >
            <img src={playstore} alt="Get it on Google Play" />
          </a>

        </div>

      </div>
    </section>
  );
}
