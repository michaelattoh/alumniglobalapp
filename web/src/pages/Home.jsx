import Navbar from "../components/Navbar";
import Hero from "../components/Hero";
import Clients from "../components/Clients";
import About from "../components/About";
import OurStory from "../components/OurStory";
import Features from "../components/Features";
import AiSection from "../components/AiSection";
import Services from "../components/Services";
import Community from "../components/community";
import Contact from "../components/Contact";
import Footer from "../components/Footer";

function Home() {
  return (
    <>
      <Navbar />
      <Hero />
      <Clients />
      <About />
      <OurStory />
      <Features />
      <AiSection />
      <Services />
      <Community />
      <Contact />
      <Footer />
    </>
  );
}

export default Home;