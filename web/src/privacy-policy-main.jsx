import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import "./index.css";
import "./styles/global.css";
import "./styles/privacy-policy.css";
import PrivacyPolicy from "./pages/PrivacyPolicy";

createRoot(document.getElementById("root")).render(
  <StrictMode>
    <PrivacyPolicy />
  </StrictMode>,
);
