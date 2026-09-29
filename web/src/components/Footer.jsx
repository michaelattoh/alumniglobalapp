import "../styles/footer.css";
import { FaTwitter, FaTiktok, FaFacebookF, FaInstagram, FaLinkedinIn } from "react-icons/fa";

export default function Footer() {

  const year = new Date().getFullYear();

  return (
    <footer className="footer">

      <div className="footer-container">

        
        <div className="footer-left">
          © {year} Alumni Global Network
        </div>

        <div className="footer-links">
          <a href="/privacy-policy.html">Privacy Policy</a>
        </div>

        
        <div className="footer-social">

          <a href="https://twitter.com" target="_blank" rel="noopener noreferrer">
            <FaTwitter />
          </a>

          <a href="https://tiktok.com" target="_blank" rel="noopener noreferrer">
            <FaTiktok />
          </a>

          <a href="https://facebook.com" target="_blank" rel="noopener noreferrer">
            <FaFacebookF />
          </a>

          <a href="https://instagram.com" target="_blank" rel="noopener noreferrer">
            <FaInstagram />
          </a>

          <a href="https://linkedin.com" target="_blank" rel="noopener noreferrer">
            <FaLinkedinIn />
          </a>

        </div>

        
        <div className="footer-right">
            Powered by 
          <a
            href="https://verixteams.co.uk/"
            target="_blank"
            rel="noopener noreferrer"
          >
            <b>  Verix Teams</b>
          </a>
        </div>

      </div>

    </footer>
  );
}
