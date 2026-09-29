import { useEffect, useState, useRef } from "react";
import "../styles/community.css";

import u1 from "../assets/images/u1.svg";
import u2 from "../assets/images/u2.svg";
import u3 from "../assets/images/u3.avif";
import u4 from "../assets/images/u4.avif";
import u5 from "../assets/images/u5.avif";
import u6 from "../assets/images/u6.avif";
import u7 from "../assets/images/u7.avif";
import u8 from "../assets/images/u8.avif";
import u9 from "../assets/images/u9.avif";
import u10 from "../assets/images/u10.avif";
import u11 from "../assets/images/u11.avif";
import u12 from "../assets/images/u12.svg";
import u13 from "../assets/images/u13.svg";

const avatars = [
  u1, u2, u3, u4, u5, u6, u7,
  u8, u9, u10, u11, u12, u13
];

export default function Community() {
  const [visible, setVisible] = useState(false);
  const [showPopup, setShowPopup] = useState(false);
  const [subscribed, setSubscribed] = useState(false);
  const [sending, setSending] = useState(false);
  const [email, setEmail] = useState("");
  const [error, setError] = useState("");
  const apiBase =
    import.meta.env.VITE_API_BASE_URL ||
    "https://api.alumniglobalnetwork.com";

  const sectionRef = useRef(null);

  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => setVisible(entry.isIntersecting),
      { threshold: 0.25 }
    );

    if (sectionRef.current) observer.observe(sectionRef.current);
    return () => observer.disconnect();
  }, []);

  const centerIndex = Math.floor(avatars.length / 2);

  const handleSend = async () => {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

    if (!emailRegex.test(email)) {
      setError("Please enter a valid email address");
      return;
    }

    setError("");
    setSending(true);
    try {
      const response = await fetch(`${apiBase}/api/newsletter/subscribe`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          email,
          source: window.location.hostname || "alumniglobalnetwork.com",
        }),
      });
      if (!response.ok) {
        const data = await response.json().catch(() => ({}));
        throw new Error(data.message || "Failed to subscribe");
      }
      setSubscribed(true);
    } catch (err) {
      setError(err.message || "Failed to subscribe");
    } finally {
      setSending(false);
    }
  };

  return (
    <section className="community-section" ref={sectionRef} id="community">
      <div className="community-container">

        <h2 className="community-title">
          Join a <span className="gradient-text">Global Alumni Community</span>
        </h2>

        <p className="community-subtitle">
          Thousands of alumni connecting, learning and growing together.
        </p>

        <div className="avatars-row">
          {avatars.map((avatar, index) => {
            const distance = Math.abs(index - centerIndex);
            const delay = distance * 0.25;

            return (
              <div
                key={index}
                className={`avatar avatar-${distance} ${
                  index === centerIndex ? "center-avatar" : ""
                } ${visible ? "show" : ""}`}
                style={{
                  animationDelay: `${delay}s`,
                  zIndex: 100 - distance
                }}
              >
                <img src={avatar} alt="member" />
              </div>
            );
          })}
        </div>

        <a
          className="join-btn"
          onClick={() => {
            setSubscribed(false);
            setSending(false);
            setEmail("");
            setError("");
            setShowPopup(true);
          }}
        >
          Join our community
        </a>

      </div>

      
      {showPopup && (
        <div className="popup-overlay">
          <div className="popup-box">

            {!subscribed ? (
              <>
                <h3>Join the Alumni Network</h3>

                <input
                  type="email"
                  placeholder="Enter your email"
                  className="popup-input"
                  value={email}
                  onChange={(e) => {
                    setEmail(e.target.value);
                    setError("");
                  }}
                />

                {error && <p className="popup-error">{error}</p>}

                <button
                  className="popup-send"
                  onClick={handleSend}
                  disabled={sending}
                >
                  {sending ? "Sending..." : "Send"}
                </button>
              </>
            ) : (
              <>
                <h3>Thank you for subscribing</h3>
                <p>We’ll get in touch shortly.</p>
              </>
            )}

            <button
              className="popup-close"
              onClick={() => setShowPopup(false)}
            >
              Close
            </button>

          </div>
        </div>
      )}
    </section>
  );
}
