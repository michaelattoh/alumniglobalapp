import { useState } from "react";
import "../styles/Navbar.css";
import logo from "../assets/images/alumni-logo.png";

function Navbar() {
  const [menuOpen, setMenuOpen] = useState(false);

  return (
    <header className="navbar">
      <div className="navbar-inner">

        <div className="logo">
          <a href="/" className="logo-link">
            <img
              src={logo}
              alt="Global Alumni Logo"
              className="logo-img"
            />
          </a>
        </div>

        <nav className={`nav-links ${menuOpen ? "active" : ""}`}>
          <a href="#about-us">About</a>
          <a href="#features">Features</a>
          <a href="#programs">Programs</a>
          <a href="#community">Community</a>
          <a href="#contact">Contact</a>
        </nav>

        <div
          className={`hamburger ${menuOpen ? "open" : ""}`}
          onClick={() => setMenuOpen(!menuOpen)}
        >
          <span></span>
          <span></span>
        </div>

      </div>
    </header>
  );
}

export default Navbar;