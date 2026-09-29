import "../styles/Services.css";
import programs from "../assets/images/programs.png";

export default function Services() {
  return (
    <section className="services-section" id="programs">

      <div className="services-container">

        <h2 className="services-title">
          Empowering Alumni Worldwide to
          <span className="gradient-text"> Learn, Connect and Grow Faster</span>
        </h2>

        <p className="services-subtitle">
          Alumni Global Network provides tools for mentorship, career
          development, collaboration, and funding opportunities—helping
          graduates connect and build meaningful impact.
        </p>

        <div className="services-image-wrapper">
          <img src={programs} alt="Programs" />
        </div>

      </div>

    </section>
  );
}