import { useState } from "react";
import "../styles/Features.css";
import bannerImg from "../assets/images/banner-card.png";

const banners = [
  { title: "Mentorship Network", text: "Connect alumni with mentors and industry leaders worldwide.", color: "bg1" },
  { title: "Networking", text: "Build meaningful alumni relationships and expand your global reach.", color: "bg2" },
  { title: "Events & Meetups", text: "Organize reunions, webinars and professional gatherings easily.", color: "bg3" },
  { title: "Career Opportunities", text: "Discover jobs, internships and collaborative opportunities.", color: "bg4" },
  { title: "Communities", text: "Create and manage alumni communities based on interests or schools.", color: "bg5" },
  { title: "Fundraising", text: "Support initiatives, scholarships and community-driven programs.", color: "bg6" },
  { title: "Analytics & Insights", text: "Track engagement, participation and alumni growth metrics.", color: "bg7" },
  { title: "Messaging & Collaboration", text: "Communicate instantly with individuals or groups worldwide.", color: "bg8" }
];

function Features() {

  
  const [index, setIndex] = useState(1);

  const next = () => {
    if (index < banners.length - 3) setIndex(index + 1);
  };

  const prev = () => {
    if (index > 0) setIndex(index - 1);
  };

  return (
    <section className="features-section" id="features">

      <div className="features-header">
        <h2>
          Powerful tools for
          <span className="gradient-text"> Alumni Growth</span>
        </h2>
        <p>Everything needed to build a thriving alumni ecosystem.</p>
      </div>

      <div className="slider-wrapper">
        <div
          className="slider-track"
          style={{ transform: `translateX(-${index * 34}%)` }}
        >
          {banners.map((banner, i) => (
            <div className={`banner-card ${banner.color}`} key={i}>

              <div className="banner-content">
                <div className="banner-title">
                  <h3>{banner.title}</h3>
                </div>

                <div className="banner-desc">
                  <p>{banner.text}</p>
                </div>
              </div>

              <div className="banner-image">
                <img src={bannerImg} alt="feature" />
              </div>

            </div>
          ))}
        </div>
      </div>

      <div className="slider-controls">
        <button onClick={prev}>‹</button>
        <button onClick={next}>›</button>
      </div>

    </section>
  );
}

export default Features;