import "../styles/OurStory.css";
import storyImage from "../assets/images/story-image.png";

function OurStory() {
  return (
    <section className="our-story" id="about">

      <div className="story-container">

        
        <div className="story-image">
          <img src={storyImage} alt="Alumni Story" />
        </div>

        
        <div className="story-text">

          <h2 className="story-title">
            The
            <span className="circle-word">
              Alumni
              <svg
                className="scribble-circle"
                viewBox="0 0 220 100"
                preserveAspectRatio="none"
              >
                <path d="M20,50 
                         C20,10 200,10 200,50
                         C200,90 20,90 20,50" />
                <path d="M30,50 
                         C30,20 190,20 190,50
                         C190,80 30,80 30,50" />
              </svg>
            </span>
            Story
          </h2>

          <p>
            The Alumni Global Network was founded to strengthen the
            connection between graduates, institutions and industry.
            We believe alumni communities hold immense potential to
            mentor, collaborate and create opportunities.
          </p>

          <p>
            Our platform empowers alumni worldwide, enabling knowledge
            sharing, career growth and meaningful partnerships across
            borders.
          </p>

        </div>

      </div>

    </section>
  );
}

export default OurStory;