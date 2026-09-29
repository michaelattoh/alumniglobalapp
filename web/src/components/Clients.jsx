import "../styles/Clients.css";

function Clients() {
  const clients = [
    "Client 1",
    "Client 2",
    "Client 3",
    "Client 4",
    "Client 5",
    "Client 6",
    "Client 7"
  ];

  const loopClients = [...clients, ...clients];

  return (
    <section className="clients">
      <div className="clients-container">

        
        <div className="clients-badge">
          <h2 className="badge-text">
            TRUSTED BY <br />
            PIONEERING <br />
            BRANDS
          </h2>

          
          <svg
            className="scribble-circle"
            viewBox="0 0 220 180"
            preserveAspectRatio="none"
          >
            <path
              d="M20,90 
                 C20,30 200,30 200,90
                 C200,150 20,150 20,90"
            />
            <path
              d="M30,90 
                 C30,40 190,40 190,90
                 C190,140 30,140 30,90"
            />
          </svg>
        </div>

        
        <div className="slider">
          <div className="slide-track">
            {loopClients.map((client, index) => (
              <div className="client-card" key={index}>
                {client}
              </div>
            ))}
          </div>
        </div>

      </div>
    </section>
  );
}

export default Clients;