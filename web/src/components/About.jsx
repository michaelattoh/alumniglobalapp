import "../styles/About.css";
import aboutImage from "../assets/images/about-mockup.png";

function About() {
  return (
    <section className="about" id="about-us">
      <div className="about-container">

        <div className="about-text">
          <h2>
            Bridging the Gap Between
            Education Sector and Industry
          </h2>

          <p>
            Alumni Global Network connects graduates, institutions and
            industry to unlock mentorship, collaboration and real
            opportunities across alumni communities worldwide.
          </p>

          <a href="#features" className="about-link">
            Explore the Vision
          </a>
        </div>

        <div className="about-image">
          <img src={aboutImage} alt="Platform Preview" />
        </div>

      </div>
    </section>
  );
}

export default About;