import "../styles/Hero.css";
import heroImage from "../assets/images/hero-illustration.png";
import appStore from "../assets/images/appstore.png";
import playStore from "../assets/images/playstore.png";

const APPLE_STORE_URL =
  "https://apps.apple.com/app/global-alumni-network/id6759199673";
const PLAY_STORE_URL =
  "https://play.google.com/store/apps/details?id=com.alumniglobalnetwork.app";

function Hero() {
  return (
    <section className="hero" id="about">
      <div className="hero-container">

        <div className="hero-left">
          <h1>
            Connect. Collaborate. <br />
            <span>Grow Through Alumni Networks</span>
          </h1>

          <p>
            Global Alumni Network helps graduates stay connected,
            discover opportunities, mentor others, and collaborate
            across institutions worldwide.
          </p>

          <div className="store-buttons">
            <a href={APPLE_STORE_URL} target="_blank" rel="noopener noreferrer">
              <img src={appStore} alt="Download on App Store" />
            </a>
            <a href={PLAY_STORE_URL} target="_blank" rel="noopener noreferrer">
              <img src={playStore} alt="Get it on Play Store" />
            </a>
          </div>
        </div>

        <div className="hero-right">
          <img src={heroImage} alt="Platform Preview" />
        </div>

      </div>
    </section>
  );
}

export default Hero;
