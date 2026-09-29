import { useEffect, useRef, useState } from "react";
import "../styles/AiSection.css";

export default function AiSection() {
  const sectionRef = useRef(null);

  const message = "Hey Amie, what can I do for you today?";
  const [typedText, setTypedText] = useState("");
  const [showSuggestions, setShowSuggestions] = useState(false);
  const [showReply, setShowReply] = useState(false);

  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          startAnimation();
        }
      },
      { threshold: 0.5 }
    );

    if (sectionRef.current) observer.observe(sectionRef.current);
    return () => observer.disconnect();
  }, []);

  const startAnimation = () => {
    setTypedText("");
    setShowSuggestions(false);
    setShowReply(false);

    let i = 0;
    const interval = setInterval(() => {
      setTypedText(message.slice(0, i + 1));
      i++;

      if (i === message.length) {
        clearInterval(interval);
        setTimeout(() => setShowSuggestions(true), 700);
        setTimeout(() => setShowReply(true), 1700);
      }
    }, 35);
  };

  return (
    <section className="ai-section" ref={sectionRef}>
      <div className="ai-container">

        <h2 className="ai-title">
          Move alumni networks forward with a{" "}
          <span className="gradient-text">built-in AI assistant</span>
        </h2>

        <p className="ai-subtitle">
          Discover insights, track careers, and unlock opportunities across your alumni community.
        </p>

        <div className="chat-wrapper">

          {/* Chat Input */}
          <div className="chat-input">

            {/* Plus icon */}
            <svg className="icon" width="18" height="18" viewBox="0 0 24 24">
              <path d="M12 5v14M5 12h14" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/>
            </svg>

            {/* Typing */}
            <div className="typing-area">
              {typedText}
              <span className="cursor">|</span>
            </div>

            {/* Mic icon */}
            <svg className="icon" width="22" height="22" viewBox="0 0 24 24">
              <path d="M12 15a3 3 0 003-3V7a3 3 0 10-6 0v5a3 3 0 003 3z" stroke="currentColor" strokeWidth="2" fill="none"/>
              <path d="M19 11a7 7 0 01-14 0M12 18v3M8 21h8" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/>
            </svg>

            {/* Send button */}
            <button className="send-btn">
                <svg width="14" height="14" viewBox="0 0 24 24">
                    <path d="M5 12h14M13 6l6 6-6 6" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
            </button>

          </div>

          {showSuggestions && (
            <div className="ai-suggestions">
              <button>Create a plan</button>
              <button>Research jobs</button>
              <button>Analyze certifications</button>
            </div>
          )}

          {showReply && (
            <div className="user-message">
              <div className="bubble">Create a plan</div>
              <div className="user-avatar">
                <svg width="16" height="16" viewBox="0 0 24 24">
                  <path d="M12 12a4 4 0 100-8 4 4 0 000 8zM4 20a8 8 0 0116 0" fill="white"/>
                </svg>
              </div>
            </div>
          )}

        </div>
      </div>
    </section>
  );
}