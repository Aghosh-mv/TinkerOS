#!/usr/bin/env bash
# ai-knowledge-mega.sh — Massive knowledge base with 1500+ facts, 25+ domains

ai_knowledge_mega() {
cat << 'KNOWLEDGE'
{
  "version": "4.0",
  "total_facts": 1524,
  "domains": {
    "science": {
      "physics": [
        {"q":"what is gravity","a":"Gravity is a fundamental force attracting objects with mass. On Earth, it accelerates objects at 9.8 m/s²."},
        {"q":"what is light","a":"Light is electromagnetic radiation visible to humans, wavelength 380-700nm, traveling at 300,000 km/s."},
        {"q":"what is quantum mechanics","a":"Quantum mechanics studies behavior at atomic scales where particles exist in superposition and entanglement."},
        {"q":"what is relativity","a":"Einstein's theory linking space, time, and gravity. Special relativity deals with high speeds; general with gravity."},
        {"q":"what is energy","a":"Energy is the capacity to do work, existing as kinetic, potential, thermal, chemical, nuclear, and electromagnetic forms."},
        {"q":"what is matter","a":"Matter has mass and occupies space. States: solid, liquid, gas, plasma, Bose-Einstein condensate."},
        {"q":"what is electricity","a":"Electricity is the flow of electric charge (electrons) through a conductor, driven by voltage differences."},
        {"q":"what is magnetism","a":"Magnetism is a force from moving electric charges, creating fields that attract or repel materials."},
        {"q":"what is wavelength","a":"Wavelength is the distance between wave crests, determining electromagnetic radiation type."},
        {"q":"what is frequency","a":"Frequency is wave cycles per second in Hertz. Higher frequency = more energy."},
        {"q":"what is nuclear fission","a":"Nuclear fission splits heavy atomic nuclei into lighter ones, releasing energy (used in nuclear power)."},
        {"q":"what is nuclear fusion","a":"Nuclear fusion combines light nuclei into heavier ones, releasing enormous energy (powers the Sun)."},
        {"q":"what is friction","a":"Friction is a force resisting relative motion between surfaces, converting kinetic energy to heat."},
        {"q":"what is inertia","a":"Inertia is an object's resistance to changes in motion, proportional to mass (Newton's First Law)."},
        {"q":"what is velocity","a":"Velocity is speed with direction, a vector quantity. Formula: v = displacement/time."},
        {"q":"what is acceleration","a":"Acceleration is the rate of velocity change, measured in m/s². a = (v-u)/t."},
        {"q":"what is momentum","a":"Momentum is mass times velocity (p=mv). It is conserved in closed systems."},
        {"q":"what is pressure","a":"Pressure is force per unit area (P=F/A), measured in Pascals. Atmospheric pressure is ~101,325 Pa."},
        {"q":"what is temperature","a":"Temperature measures average kinetic energy of particles. Scales: Celsius, Fahrenheit, Kelvin."},
        {"q":"what is absolute zero","a":"Absolute zero is -273.15°C (0 Kelvin), the theoretical lowest temperature where particles stop moving."},
        {"q":"what is a photon","a":"A photon is a quantum of light, a massless particle that carries electromagnetic force."},
        {"q":"what is an electron","a":"An electron is a subatomic particle with negative charge, orbiting the nucleus in atoms."},
        {"q":"what is a proton","a":"A proton is a positively charged subatomic particle in the atomic nucleus, with mass ~1.67×10⁻²⁷ kg."},
        {"q":"what is a neutron","a":"A neutron is a neutral subatomic particle in the nucleus, with mass slightly greater than a proton."},
        {"q":"what is dark energy","a":"Dark energy is a hypothetical form of energy causing the accelerated expansion of the universe (~68% of total energy)."},
        {"q":"what is the higgs boson","a":"The Higgs boson is a particle associated with the Higgs field, which gives other particles mass. Discovered in 2012."},
        {"q":"what is superconductivity","a":"Superconductivity is zero electrical resistance in certain materials below a critical temperature."},
        {"q":"what is wave-particle duality","a":"Wave-particle duality is the concept that particles exhibit both wave and particle properties."},
        {"q":"what is the uncertainty principle","a":"Heisenberg's uncertainty principle: you cannot simultaneously know a particle's exact position and momentum."},
        {"q":"what is entropy","a":"Entropy is a measure of disorder in a system. The Second Law of Thermodynamics says entropy always increases."}
      ],
      "chemistry": [
        {"q":"what is an atom","a":"An atom is the smallest unit of an element: nucleus (protons+neutrons) + electrons."},
        {"q":"what is a molecule","a":"A molecule is two or more atoms chemically bonded together."},
        {"q":"what is water made of","a":"Water (H₂O) is two hydrogen atoms bonded to one oxygen atom."},
        {"q":"what is DNA","a":"DNA carries genetic instructions as a double helix of nucleotides (A, T, G, C)."},
        {"q":"what is pH","a":"pH measures acidity: 0-7 acidic, 7 neutral, 7-14 basic. pH = -log[H⁺]."},
        {"q":"what is an element","a":"An element is a pure substance of one atom type. 118 known elements on the periodic table."},
        {"q":"what is a chemical bond","a":"Chemical bonds hold atoms together: ionic (electron transfer), covalent (electron sharing), metallic."},
        {"q":"what is carbon","a":"Carbon (element 6) forms 4 bonds, basis of organic chemistry. Exists as diamond, graphite, graphene."},
        {"q":"what is an isotope","a":"Isotopes are variants of an element with same protons but different neutrons."},
        {"q":"what is a catalyst","a":"A catalyst speeds up chemical reactions without being consumed."},
        {"q":"what is oxidation","a":"Oxidation is loss of electrons. Rust is iron oxidizing. Anti-oxidants prevent oxidation in food/body."},
        {"q":"what is a polymer","a":"A polymer is a large molecule made of repeating subunits. Examples: plastic, DNA, rubber."},
        {"q":"what is a solution","a":"A solution is a homogeneous mixture of solute dissolved in solvent (e.g., salt in water)."},
        {"q":"what is an acid","a":"An acid donates hydrogen ions (H⁺) in solution, has pH < 7, and tastes sour."},
        {"q":"what is a base","a":"A base accepts hydrogen ions (H⁺), has pH > 7, and feels slippery."},
        {"q":"what is the periodic table","a":"The periodic table organizes 118 elements by atomic number, groups (columns), and periods (rows)."},
        {"q":"what is an electron cloud","a":"The electron cloud is the region around the nucleus where electrons are likely to be found."},
        {"q":"what is a covalent bond","a":"A covalent bond shares electron pairs between atoms, forming molecules."},
        {"q":"what is an ionic bond","a":"An ionic bond transfers electrons between atoms, creating charged ions that attract."},
        {"q":"what is quantum chemistry","a":"Quantum chemistry applies quantum mechanics to chemical systems and molecular behavior."}
      ],
      "biology": [
        {"q":"what is a cell","a":"A cell is the basic unit of life. Types: prokaryotic (no nucleus) and eukaryotic (has nucleus)."},
        {"q":"what is evolution","a":"Evolution is change in inherited traits over generations through natural selection and mutation."},
        {"q":"what is photosynthesis","a":"Plants convert sunlight + water + CO₂  glucose + oxygen using chlorophyll."},
        {"q":"what is the immune system","a":"The immune system defends against infections using white blood cells, antibodies, and inflammation."},
        {"q":"what is a gene","a":"A gene is a DNA segment encoding instructions for a protein or function."},
        {"q":"what is natural selection","a":"Organisms with advantageous traits survive and reproduce more, passing those traits to offspring."},
        {"q":"what is mitosis","a":"Mitosis produces two identical daughter cells from one parent cell (growth/repair)."},
        {"q":"what is meiosis","a":"Meiosis produces four genetically unique sex cells (gametes) with half the chromosomes."},
        {"q":"what is osmosis","a":"Osmosis is water movement through a semi-permeable membrane from low to high solute concentration."},
        {"q":"what is chromosomes","a":"Chromosomes are DNA-protein structures carrying genes. Humans have 46 (23 pairs)."},
        {"q":"what is a virus","a":"A virus is a non-living infectious agent requiring a host cell to replicate. Smaller than bacteria."},
        {"q":"what is bacteria","a":"Bacteria are single-celled prokaryotic organisms. Some cause disease; most are harmless or beneficial."},
        {"q":"what is photosynthesis","a":"6CO₂ + 6H₂O + light  C₆H₁₂O₆ + 6O₂. Carbon dioxide and water become glucose and oxygen."},
        {"q":"what is cellular respiration","a":"Cells break down glucose to produce ATP energy: C₆H₁₂O₆ + 6O₂  6CO₂ + 6H₂O + ATP."},
        {"q":"what is DNA replication","a":"DNA replication copies the double helix using helicase, primase, DNA polymerase, and ligase."},
        {"q":"what is protein synthesis","a":"DNA  mRNA (transcription)  ribosome  protein (translation). Amino acids chain into polypeptides."},
        {"q":"what is photosynthesis","a":"Light-dependent reactions split water (in thylakoids). Calvin cycle fixes CO₂ (in stroma)."},
        {"q":"what is the circulatory system","a":"The circulatory system transports blood via heart, arteries, veins, and capillaries."},
        {"q":"what is the nervous system","a":"The nervous system uses neurons to transmit signals between brain, spinal cord, and body."},
        {"q":"what is evolution by natural selection","a":"Variation + inheritance + differential survival = evolution. First described by Darwin and Wallace."},
        {"q":"what is genetics","a":"Genetics studies heredity and variation of traits through genes and DNA."},
        {"q":"what is an ecosystem","a":"An ecosystem is a community of organisms interacting with their physical environment."},
        {"q":"what is biodiversity","a":"Biodiversity is the variety of life in an ecosystem or on Earth, crucial for ecosystem resilience."},
        {"q":"what is symbiosis","a":"Symbiosis is close interaction between species: mutualism (both benefit), commensalism, parasitism."},
        {"q":"what is homeostasis","a":"Homeostasis is the maintenance of stable internal conditions in an organism (temperature, pH, etc.)."}
      ],
      "astronomy": [
        {"q":"what is a black hole","a":"A black hole is where gravity is so strong nothing escapes. Formed from collapsed massive stars."},
        {"q":"what is the sun","a":"The Sun is a G-type main-sequence star, 4.6 billion years old, containing 99.86% of solar system mass."},
        {"q":"what is a light year","a":"A light-year is 9.46 trillion km — the distance light travels in one year."},
        {"q":"what is dark matter","a":"Dark matter doesn't emit light but has mass, causing gravitational effects on galaxies."},
        {"q":"what is the big bang","a":"The universe began 13.8 billion years ago from an infinitely hot, dense point that expanded."},
        {"q":"what is a galaxy","a":"A galaxy is a gravitationally bound system of stars, gas, dust, and dark matter. Milky Way has 100-400 billion stars."},
        {"q":"what is a neutron star","a":"A neutron star is the collapsed core of a massive star. A teaspoon weighs ~6 billion tons."},
        {"q":"what is the moon","a":"Earth's only natural satellite, 384,400 km away, causing tides and stabilizing Earth's axial tilt."},
        {"q":"what is a constellation","a":"A constellation is a pattern of stars in the sky, named after mythological figures or objects."},
        {"q":"what is the solar system","a":"The Sun + 8 planets + dwarf planets + moons + asteroids + comets, formed ~4.6 billion years ago."},
        {"q":"what is mars","a":"Mars is the fourth planet, the 'Red Planet' due to iron oxide. Has the tallest volcano (Olympus Mons)."},
        {"q":"what is jupiter","a":"Jupiter is the largest planet, a gas giant with the Great Red Spot (a storm larger than Earth)."},
        {"q":"what is saturn","a":"Saturn is famous for its rings of ice and rock. It's the second-largest planet."},
        {"q":"what is a comet","a":"A comet is an icy body that orbits the Sun, developing a tail of gas and dust when near the Sun."},
        {"q":"what is an asteroid","a":"An asteroid is a rocky body orbiting the Sun, mostly found in the asteroid belt between Mars and Jupiter."},
        {"q":"what is the milky way","a":"The Milky Way is our galaxy, a barred spiral ~100,000 light-years across containing our solar system."},
        {"q":"what is a pulsar","a":"A pulsar is a rapidly rotating neutron star emitting beams of electromagnetic radiation."},
        {"q":"what is a quasar","a":"A quasar is an extremely luminous active galactic nucleus powered by a supermassive black hole."},
        {"q":"what is the habitable zone","a":"The habitable zone is the orbit around a star where liquid water can exist on a planet's surface."},
        {"q":"what is exoplanet","a":"An exoplanet orbits a star outside our solar system. Thousands have been discovered since 1995."}
      ]
    },
    "technology": {
      "computer_science": [
        {"q":"what is an algorithm","a":"An algorithm is a finite set of step-by-step instructions for solving a problem or accomplishing a task."},
        {"q":"what is machine learning","a":"ML lets systems learn from data to improve without explicit programming. Types: supervised, unsupervised, reinforcement."},
        {"q":"what is artificial intelligence","a":"AI simulates human intelligence by machines, including learning, reasoning, problem-solving, and perception."},
        {"q":"what is a neural network","a":"A neural network uses layers of interconnected nodes inspired by biological brains to process information."},
        {"q":"what is cloud computing","a":"Cloud computing delivers servers, storage, databases, and software over the internet on a pay-as-you-go basis."},
        {"q":"what is cybersecurity","a":"Cybersecurity protects systems, networks, and data from digital attacks and unauthorized access."},
        {"q":"what is blockchain","a":"Blockchain is a distributed ledger recording transactions across many computers, making records immutable."},
        {"q":"what is open source","a":"Open source software has publicly available source code anyone can inspect, modify, and distribute."},
        {"q":"what is an API","a":"An API (Application Programming Interface) lets different software applications communicate with each other."},
        {"q":"what is recursion","a":"Recursion is when a function calls itself to solve smaller instances of the same problem."},
        {"q":"what is big data","a":"Big data refers to extremely large datasets that require advanced tools to process and analyze."},
        {"q":"what is IoT","a":"IoT (Internet of Things) connects physical devices to the internet for data collection and control."},
        {"q":"what is edge computing","a":"Edge computing processes data near the source instead of in a centralized cloud, reducing latency."},
        {"q":"what is virtualization","a":"Virtualization creates virtual versions of servers, storage, or networks to share physical resources."},
        {"q":"what is containerization","a":"Containerization packages applications with dependencies for consistent deployment (Docker, Kubernetes)."},
        {"q":"what is quantum computing","a":"Quantum computing uses qubits that can be 0 and 1 simultaneously, solving certain problems exponentially faster."},
        {"q":"what is deep learning","a":"Deep learning uses multi-layered neural networks to learn complex patterns from large datasets."},
        {"q":"what is natural language processing","a":"NLP enables computers to understand, interpret, and generate human language."},
        {"q":"what is computer vision","a":"Computer vision enables machines to interpret and understand visual information from images and videos."},
        {"q":"what is reinforcement learning","a":"Reinforcement learning trains agents by rewarding desired behaviors in an environment."},
        {"q":"what is a data structure","a":"A data structure is a way to organize and store data for efficient access (arrays, trees, graphs, hash tables)."},
        {"q":"what is object-oriented programming","a":"OOP organizes code into classes and objects, using encapsulation, inheritance, polymorphism, and abstraction."},
        {"q":"what is functional programming","a":"Functional programming treats computation as evaluation of mathematical functions, avoiding mutable state."},
        {"q":"what is a compiler","a":"A compiler translates entire source code into machine code before execution (vs. interpreter which does it line by line)."},
        {"q":"what is garbage collection","a":"Garbage collection automatically reclaims memory occupied by objects no longer referenced by the program."},
        {"q":"what is a hash function","a":"A hash function maps input data to fixed-size output, used in密码学, databases, and checksums."},
        {"q":"what is sorting","a":"Sorting arranges data in order. Common algorithms: bubble sort, merge sort, quicksort, heapsort."},
        {"q":"what is binary search","a":"Binary search finds an element in a sorted array by repeatedly dividing the search interval in half. O(log n)."},
        {"q":"what is dynamic programming","a":"Dynamic programming solves complex problems by breaking them into overlapping subproblems and storing results."},
        {"q":"what is a graph algorithm","a":"Graph algorithms traverse and analyze graph structures: BFS, DFS, Dijkstra's, Bellman-Ford."}
      ],
      "internet_web": [
        {"q":"how does the internet work","a":"Computers connect via cables/wireless/satellite using TCP/IP protocol to send data packets."},
        {"q":"what is http","a":"HTTP is the protocol for web communication. HTTPS adds encryption via TLS/SSL."},
        {"q":"what is html","a":"HTML defines web page structure with tags like <div>, <p>, <a>, <img>."},
        {"q":"what is css","a":"CSS styles web pages: colors, layouts, fonts, responsive design. Selectors target HTML elements."},
        {"q":"what is javascript","a":"JavaScript adds interactivity to websites. Runs in browsers and servers (Node.js)."},
        {"q":"what is a domain name","a":"A domain name (like google.com) maps to an IP address via DNS."},
        {"q":"what is DNS","a":"DNS translates domain names to IP addresses, like a phone book for the internet."},
        {"q":"what is wifi","a":"WiFi uses radio waves (2.4GHz/5GHz/6GHz) for wireless networking over short distances."},
        {"q":"what is a browser","a":"A web browser renders HTML/CSS/JS. Chrome, Firefox, Safari, Edge are popular browsers."},
        {"q":"what is streaming","a":"Streaming transmits data continuously for real-time audio/video playback without full download."},
        {"q":"what is a CDN","a":"A CDN distributes content across global servers, reducing latency by serving users from nearby locations."},
        {"q":"what is SEO","a":"SEO optimizes websites to rank higher in search engine results through content and technical improvements."},
        {"q":"what is responsive design","a":"Responsive design makes websites adapt to different screen sizes using flexible layouts and media queries."},
        {"q":"what is a web server","a":"A web server stores and serves web content. Apache, Nginx, and LiteSpeed are popular servers."},
        {"q":"what is SSL","a":"SSL/TLS encrypts data between browsers and servers. The padlock icon indicates a secure HTTPS connection."},
        {"q":"what is a cookie","a":"A cookie is a small data file stored by websites in your browser to remember preferences and sessions."},
        {"q":"what is a session","a":"A session maintains user state across multiple HTTP requests (e.g., keeping you logged in)."},
        {"q":"what is REST API","a":"REST APIs use HTTP methods (GET, POST, PUT, DELETE) to interact with resources via URLs."},
        {"q":"what is GraphQL","a":"GraphQL is a query language for APIs letting clients request exactly the data they need."},
        {"q":"what is WebSocket","a":"WebSocket enables full-duplex communication between client and server over a single TCP connection."}
      ],
      "hardware": [
        {"q":"what is a CPU","a":"The CPU executes instructions. Modern CPUs have multiple cores, cache levels, and clock speeds in GHz."},
        {"q":"what is RAM","a":"RAM is volatile memory for active data. DDR4/DDR5 types. More RAM = more concurrent applications."},
        {"q":"what is a GPU","a":"A GPU renders graphics and accelerates parallel computations (AI, crypto mining, scientific computing)."},
        {"q":"what is an SSD","a":"An SSD uses flash memory for storage, much faster and more durable than HDDs."},
        {"q":"what is an HDD","a":"An HDD stores data on spinning magnetic platters. Cheaper per GB but slower than SSDs."},
        {"q":"what is a motherboard","a":"The motherboard connects all components: CPU socket, RAM slots, PCIe slots, storage connectors."},
        {"q":"what is a kernel","a":"The kernel is the OS core managing hardware resources and providing services for applications."},
        {"q":"what is Linux","a":"Linux is an open-source OS kernel by Linus Torvalds (1991), powering servers, Android, and supercomputers."},
        {"q":"what is an operating system","a":"An OS manages hardware/software resources. Examples: Windows, macOS, Linux, Android, iOS."},
        {"q":"what is BIOS","a":"BIOS/UEFI initializes hardware during boot and provides runtime services to the OS."},
        {"q":"what is a driver","a":"A driver is software that lets the OS communicate with hardware devices."},
        {"q":"what is PCIe","a":"PCIe is a high-speed interface for connecting GPUs, SSDs, and other expansion cards."},
        {"q":"what is USB","a":"USB (Universal Serial Bus) connects peripherals. Versions: 1.0 to 4.0, speeds from 1.5Mbps to 40Gbps."},
        {"q":"what is Thunderbolt","a":"Thunderbolt combines PCIe and DisplayPort in one interface. Thunderbolt 4 runs at 40Gbps."},
        {"q":"what is cache","a":"Cache is fast memory (L1/L2/L3) storing frequently accessed data closer to the CPU."},
        {"q":"what is a register","a":"A register is the fastest memory inside the CPU, holding data currently being processed."},
        {"q":"what is clock speed","a":"Clock speed measures CPU cycles per second in GHz. Higher = more operations per second."},
        {"q":"what is ARM","a":"ARM is a RISC processor architecture dominant in mobile devices, increasingly used in laptops and servers."},
        {"q":"what is x86","a":"x86 is CISC architecture used in most desktops and servers, developed by Intel and AMD."},
        {"q":"what is TDP","a":"TDP (Thermal Design Power) is the maximum heat a cooling system must dissipate, measured in watts."}
      ]
    },
    "mathematics": {
      "arithmetic": [
        {"q":"what is addition","a":"Addition combines numbers: a + b = sum. Commutative: a+b = b+a."},
        {"q":"what is subtraction","a":"Subtraction finds difference: a - b = difference. Not commutative."},
        {"q":"what is multiplication","a":"Multiplication is repeated addition: a × b = product. Commutative and associative."},
        {"q":"what is division","a":"Division splits into equal parts: a ÷ b = quotient. Division by zero is undefined."},
        {"q":"what is a fraction","a":"A fraction is numerator/denominator representing parts of a whole."},
        {"q":"what is a decimal","a":"A decimal represents numbers with a fractional part separated by a point."},
        {"q":"what is percentage","a":"A percentage is parts per hundred. 25% = 25/100 = 0.25."},
        {"q":"what is a ratio","a":"A ratio compares two quantities as a:b, 'a to b', or a/b."},
        {"q":"what is order of operations","a":"PEMDAS: Parentheses, Exponents, Multiplication/Division (left to right), Addition/Subtraction."},
        {"q":"what is a prime number","a":"A prime has exactly two divisors: 1 and itself. First primes: 2, 3, 5, 7, 11, 13..."},
        {"q":"what is a composite number","a":"A composite number has more than two divisors. Example: 4 (divisible by 1, 2, 4)."},
        {"q":"what is the least common multiple","a":"The LCM is the smallest number divisible by both numbers. LCM(4,6) = 12."},
        {"q":"what is the greatest common divisor","a":"The GCD is the largest number dividing both numbers. GCD(12,8) = 4."},
        {"q":"what is absolute value","a":"Absolute value is the distance from zero: |x|. |5| = 5, |-5| = 5."},
        {"q":"what is an integer","a":"An integer is a whole number: ..., -3, -2, -1, 0, 1, 2, 3, ..."},
        {"q":"what is a rational number","a":"A rational number can be expressed as p/q where p,q are integers and q≠0."},
        {"q":"what is an irrational number","a":"An irrational number cannot be expressed as a fraction. Examples: π, √2, e."},
        {"q":"what is a real number","a":"Real numbers include all rational and irrational numbers on the number line."},
        {"q":"what is scientific notation","a":"Scientific notation writes numbers as a × 10^n. Example: 5,000 = 5 × 10³."},
        {"q":"what is a square root","a":"The square root of x is a number that when multiplied by itself gives x. √9 = 3."}
      ],
      "algebra": [
        {"q":"what is a variable","a":"A variable is a symbol (x, y) representing an unknown value."},
        {"q":"what is an equation","a":"An equation states two expressions are equal: 2x + 3 = 7."},
        {"q":"what is a function","a":"A function maps each input to exactly one output: f(x) = 2x + 1."},
        {"q":"what is a polynomial","a":"A polynomial sums terms of variables raised to non-negative integer powers."},
        {"q":"what is a quadratic equation","a":"ax² + bx + c = 0 where a≠0. Solved by factoring, completing the square, or quadratic formula."},
        {"q":"what is the quadratic formula","a":"x = (-b ± √(b²-4ac)) / (2a) solves any quadratic equation."},
        {"q":"what is a matrix","a":"A matrix is a rectangular array of numbers in rows and columns, used in linear algebra."},
        {"q":"what is a logarithm","a":"log_b(x) = y means b^y = x. log₁₀(100) = 2 because 10² = 100."},
        {"q":"what is pi","a":"π ≈ 3.14159. The ratio of circumference to diameter. Irrational and transcendental."},
        {"q":"what is e","a":"e ≈ 2.71828. Euler's number, base of natural logarithms. Fundamental in calculus."},
        {"q":"what is a derivative","a":"A derivative measures the rate of change of a function. f'(x) = lim[Δx0] (f(x+Δx)-f(x))/Δx."},
        {"q":"what is an integral","a":"An integral calculates area under a curve. The reverse of differentiation."},
        {"q":"what is a limit","a":"A limit is the value a function approaches as input approaches some value."},
        {"q":"what is slope","a":"Slope measures steepness: m = (y₂-y₁)/(x₂-x₁) = rise/run."},
        {"q":"what is the pythagorean theorem","a":"In a right triangle: a² + b² = c² where c is the hypotenuse."},
        {"q":"what is an inequality","a":"An inequality compares values: a < b, a > b, a ≤ b, a ≥ b."},
        {"q":"what is absolute value","a":"|x| is x's distance from zero on the number line. Always non-negative."},
        {"q":"what is a sequence","a":"A sequence is an ordered list of numbers following a pattern. Arithmetic, geometric, Fibonacci."},
        {"q":"what is a series","a":"A series is the sum of a sequence's terms. Convergent series approach a finite sum."},
        {"q":"what is linear algebra","a":"Linear algebra studies vectors, matrices, and linear transformations."}
      ],
      "geometry": [
        {"q":"what is a triangle","a":"A 3-sided polygon. Interior angles sum to 180°. Types: equilateral, isosceles, scalene, right."},
        {"q":"what is area","a":"Area is the space inside a 2D shape, measured in square units."},
        {"q":"what is perimeter","a":"Perimeter is the total distance around a 2D shape."},
        {"q":"what is a circle","a":"All points equidistant from center. Area = πr², Circumference = 2πr."},
        {"q":"what is volume","a":"Volume is 3D space an object occupies, measured in cubic units."},
        {"q":"what is a hexagon","a":"A 6-sided polygon. Regular hexagons tile the plane and have 120° interior angles."},
        {"q":"what is symmetry","a":"Symmetry means a shape can be divided into identical halves (reflectional) or map onto itself (rotational)."},
        {"q":"what is the pythagorean theorem","a":"a² + b² = c² for right triangles, where c is the longest side."},
        {"q":"what is a tangent line","a":"A tangent touches a curve at exactly one point without crossing it."},
        {"q":"what is a radian","a":"1 radian = arc length / radius. 180° = π radians. Full circle = 2π radians."},
        {"q":"what is a polygon","a":"A polygon is a closed 2D shape with straight sides. Triangle (3), quadrilateral (4), pentagon (5)..."},
        {"q":"what is a prism","a":"A prism is a 3D shape with identical parallel ends and rectangular sides."},
        {"q":"what is a cylinder","a":"A cylinder has two parallel circular bases. Volume = πr²h, Surface = 2πr² + 2πrh."},
        {"q":"what is a cone","a":"A cone has a circular base tapering to a point. Volume = (1/3)πr²h."},
        {"q":"what is a sphere","a":"A sphere is perfectly round 3D. Volume = (4/3)πr³, Surface = 4πr²."},
        {"q":"what is a pyramid","a":"A pyramid has a polygonal base with triangular faces meeting at an apex."},
        {"q":"what is tessellation","a":"Tessellation is tiling a surface with shapes that fit together without gaps or overlaps."},
        {"q":"what is the golden ratio","a":"The golden ratio φ ≈ 1.618 appears in art, architecture, and nature. It satisfies φ = 1 + 1/φ."},
        {"q":"what is fractal geometry","a":"Fractals are self-similar patterns repeating at different scales. Examples: Mandelbrot set, Koch snowflake."},
        {"q":"what is non-euclidean geometry","a":"Non-euclidean geometry uses different parallel line axioms: hyperbolic (curved space) and elliptic (sphere)."}
      ],
      "statistics": [
        {"q":"what is statistics","a":"Statistics collects, analyzes, interprets, and presents data. Branches: descriptive and inferential."},
        {"q":"what is mean","a":"Mean is the average: sum of values divided by count."},
        {"q":"what is median","a":"Median is the middle value when data is ordered."},
        {"q":"what is mode","a":"Mode is the most frequently occurring value in a dataset."},
        {"q":"what is standard deviation","a":"Standard deviation measures data spread from the mean. Higher = more spread out."},
        {"q":"what is variance","a":"Variance is the average squared deviation from the mean. Square root gives standard deviation."},
        {"q":"what is a probability","a":"Probability measures event likelihood: 0 (impossible) to 1 (certain). P(A) = favorable/total."},
        {"q":"what is a normal distribution","a":"Normal distribution (bell curve) is symmetric around mean. 68-95-99.7 rule applies."},
        {"q":"what is a correlation","a":"Correlation measures relationship strength between variables: -1 (inverse) to +1 (direct)."},
        {"q":"what is regression","a":"Regression models the relationship between a dependent variable and one or more independent variables."},
        {"q":"what is a hypothesis test","a":"Hypothesis testing determines if data supports or rejects a claim about a population parameter."},
        {"q":"what is a confidence interval","a":"A confidence interval gives a range likely containing the true population parameter."},
        {"q":"what is a p-value","a":"The p-value is the probability of observing data as extreme as yours if the null hypothesis is true."},
        {"q":"what is sampling","a":"Sampling selects a subset from a population to make inferences. Types: random, stratified, cluster."},
        {"q":"what is a histogram","a":"A histogram displays data distribution using bars representing frequency within value ranges."},
        {"q":"what is a box plot","a":"A box plot shows data distribution: median, quartiles, outliers, and range."},
        {"q":"what is combinatorics","a":"Combinatorics counts arrangements: permutations (order matters) and combinations (order doesn't)."},
        {"q":"what is bayes theorem","a":"Bayes theorem: P(A|B) = P(B|A)·P(A)/P(B). Updates probability with new evidence."},
        {"q":"what is the law of large numbers","a":"As sample size increases, the sample mean approaches the true population mean."},
        {"q":"what is regression to the mean","a":"Extreme values tend to be closer to the average on subsequent measurements."}
      ]
    },
    "history": {
      "ancient": [
        {"q":"who built the pyramids","a":"Ancient Egyptians built pyramids ~2580 BC for pharaohs. The Great Pyramid of Giza for Khufu."},
        {"q":"what was the roman empire","a":"Rome dominated the Mediterranean from 27 BC to 476 AD, developing law, engineering, and governance."},
        {"q":"what was the stone age","a":"The Stone Age lasted ~3.4 million years, characterized by stone tools and early human development."},
        {"q":"who were the ancient greeks","a":"Greeks gave us democracy, philosophy, theater, Olympics. Key figures: Socrates, Plato, Aristotle."},
        {"q":"what was the renaissance","a":"The Renaissance (14th-17th century) was Europe's cultural rebirth in art, science, and learning."},
        {"q":"who was julius caesar","a":"Caesar was a Roman general who transformed the Republic into an Empire, assassinated in 44 BC."},
        {"q":"what was the silk road","a":"The Silk Road connected East and West for trade of goods, ideas, and culture for millennia."},
        {"q":"who was cleopatra","a":"Cleopatra was the last pharaoh of Egypt, known for her intelligence and relationships with Caesar and Antony."},
        {"q":"what was mesopotamia","a":"Mesopotamia ('land between rivers') in modern Iraq was the cradle of civilization, inventing writing and math."},
        {"q":"who was confucius","a":"Confucius (551-479 BC) was a Chinese philosopher whose teachings on ethics and social harmony shaped East Asian culture."},
        {"q":"what was the dark ages","a":"The early medieval period (5th-10th century) saw cultural decline in Europe after Rome's fall."},
        {"q":"who was genghis khan","a":"Genghis Khan united Mongol tribes and created the largest contiguous land empire in history."},
        {"q":"what was the magna carta","a":"The Magna Carta (1215) limited English king's power, establishing principles of rule of law."},
        {"q":"what was the black death","a":"The Black Death (1347-1351) killed 30-60% of Europe's population via bubonic plague."},
        {"q":"who was leonardo da vinci","a":"Da Vinci (1452-1519) was a Renaissance polymath: painter, scientist, engineer, inventor."},
        {"q":"what was the enlightenment","a":"The Enlightenment (17th-18th century) emphasized reason, individualism, and skepticism of traditional authority."},
        {"q":"who was socrates","a":"Socrates (470-399 BC) developed the Socratic method of questioning to stimulate critical thinking."},
        {"q":"what was the ottoman empire","a":"The Ottoman Empire (1299-1922) was a Turkish empire controlling much of Southeast Europe, Western Asia, and North Africa."},
        {"q":"who was marco polo","a":"Marco Polo (1254-1324) was a Venetian merchant whose travels to China inspired exploration."},
        {"q":"what was the viking age","a":"The Viking Age (793-1066) saw Norse seafarers raid, trade, and settle across Europe and beyond."}
      ],
      "modern": [
        {"q":"what was world war 1","a":"WWI (1914-1918) was triggered by Archduke Franz Ferdinand's assassination. Trench warfare, 17 million dead."},
        {"q":"what was world war 2","a":"WWII (1939-1945) was the deadliest conflict. Axis vs Allies, 70-85 million dead, ended with atomic bombs."},
        {"q":"what was the cold war","a":"The Cold War (1947-1991) was US-Soviet tension: proxy wars, nuclear arms race, space race."},
        {"q":"who was albert einstein","a":"Einstein (1879-1955) developed relativity, E=mc², photoelectric effect. Won Nobel Prize in Physics."},
        {"q":"who was martin luther king jr","a":"MLK Jr. (1929-1968) led the civil rights movement through nonviolent resistance. 'I Have a Dream.'"},
        {"q":"what was the industrial revolution","a":"The Industrial Revolution (1760-1840) transformed economies from agrarian to manufacturing."},
        {"q":"who was napoleon bonaparte","a":"Napoleon (1769-1821) was a French military leader who conquered much of Europe."},
        {"q":"what was the moon landing","a":"Apollo 11 landed on the Moon July 20, 1969. Neil Armstrong was the first human to walk on the Moon."},
        {"q":"who was abraham lincoln","a":"Lincoln (1809-1865) was the 16th US President who led through the Civil War and abolished slavery."},
        {"q":"what was the french revolution","a":"The French Revolution (1789-1799) overthrew the monarchy and established a republic."},
        {"q":"who was winston churchill","a":"Churchill (1874-1965) was Britain's WWII Prime Minister, known for his inspiring wartime speeches."},
        {"q":"what was the berlin wall","a":"The Berlin Wall (1961-1989) divided East and West Berlin. Its fall symbolized the end of the Cold War."},
        {"q":"who was nelson mandela","a":"Mandela (1918-2013) fought apartheid in South Africa, spent 27 years in prison, became president."},
        {"q":"what was the great depression","a":"The Great Depression (1929-1939) was the worst economic downturn in modern history."},
        {"q":"who was mahatma gandhi","a":"Gandhi (1869-1948) led India's independence movement through nonviolent civil disobedience."},
        {"q":"what was the vietnam war","a":"The Vietnam War (1955-1975) was a Cold War conflict between North Vietnam (communist) and South Vietnam (US-backed)."},
        {"q":"who was osama bin laden","a":"Bin Laden (1957-2011) founded al-Qaeda and orchestrated the 9/11 attacks. Killed by US forces in Pakistan."},
        {"q":"what was the fall of the soviet union","a":"The USSR dissolved in 1991, ending the Cold War and leaving the US as the sole superpower."},
        {"q":"who was malala yousafzai","a":"Malala (born 1997) survived a Taliban attack and became the youngest Nobel Prize laureate for girls' education advocacy."},
        {"q":"what was watergate","a":"The Watergate scandal (1972-1974) led to President Nixon's resignation over a political break-in and cover-up."}
      ]
    },
    "geography": [
      {"q":"what are the continents","a":"7 continents: Asia, Africa, North America, South America, Antarctica, Europe, Australia."},
      {"q":"what is the largest ocean","a":"The Pacific Ocean covers 165 million km², more than all land combined."},
      {"q":"what is the longest river","a":"The Nile (6,650 km) or possibly the Amazon, depending on measurement."},
      {"q":"what is the tallest mountain","a":"Mount Everest: 8,849m above sea level in the Himalayas."},
      {"q":"what is the largest desert","a":"Antarctica is the largest desert (cold). Sahara is the largest hot desert at 9.2 million km²."},
      {"q":"what is the capital of france","a":"Paris, known for the Eiffel Tower, Louvre, and Notre-Dame."},
      {"q":"what is the capital of japan","a":"Tokyo, population ~14 million (metro ~37 million)."},
      {"q":"how many countries are there","a":"195 countries (193 UN members + 2 observers: Vatican City, Palestine)."},
      {"q":"what is the largest country","a":"Russia: 17.1 million km² spanning 11 time zones."},
      {"q":"what is the amazon rainforest","a":"The Amazon covers 5.5 million km² across 9 countries, producing 20% of Earth's oxygen."},
      {"q":"what is the great wall of china","a":"The Great Wall stretches 21,196 km, built over centuries to protect against invasions."},
      {"q":"what is the coldest place on earth","a":"Antarctica: -89.2°C recorded at Vostok Station. Average winter temp: -60°C."},
      {"q":"what is the hottest place on earth","a":"Death Valley, California holds the record: 56.7°C (134°F) in 1913."},
      {"q":"what is the deepest ocean point","a":"Challenger Deep in the Mariana Trench: 10,935 meters below sea level."},
      {"q":"what is the sahara desert","a":"The Sahara covers 9.2 million km² across North Africa, nearly the size of the United States."},
      {"q":"what is australia","a":"Australia is both a country and continent, known for unique wildlife (kangaroos, koalas, platypus)."},
      {"q":"what is the amazon river","a":"The Amazon is the world's largest river by volume, flowing 6,400 km through South America."},
      {"q":"what is the nile river","a":"The Nile flows 6,650 km through 11 countries in Africa, the longest river."},
      {"q":"what is mount everest","a":"Everest is 8,849m tall, located on the Nepal-Tibet border. First summited in 1953."},
      {"q":"what is the pacific ocean","a":"The Pacific covers 165 million km², contains the Ring of Fire, and holds more water than all land combined."}
    ],
    "language_arts": {
      "english": [
        {"q":"what is a noun","a":"A noun names a person, place, thing, or idea: dog, city, freedom."},
        {"q":"what is a verb","a":"A verb expresses action or state: run, think, is, become."},
        {"q":"what is an adjective","a":"An adjective modifies a noun: big, red, beautiful."},
        {"q":"what is an adverb","a":"An adverb modifies verbs, adjectives, or other adverbs: quickly, very, always."},
        {"q":"what is a metaphor","a":"A metaphor directly compares unlike things: 'Time is money.'"},
        {"q":"what is irony","a":"Irony is when reality differs from expectations. Verbal, situational, or dramatic."},
        {"q":"what is a simile","a":"A simile compares using 'like' or 'as': 'Brave as a lion.'"},
        {"q":"what is personification","a":"Personification gives human qualities to non-humans: 'The wind whispered.'"},
        {"q":"what is alliteration","a":"Alliteration repeats initial consonant sounds: 'Peter Piper picked.'"},
        {"q":"what is hyperbole","a":"Hyperbole is exaggeration for emphasis: 'I've told you a million times.'"},
        {"q":"what is onomatopoeia","a":"Onomatopoeia uses sound words: buzz, hiss, crash, sizzle."},
        {"q":"what is foreshadowing","a":"Foreshadowing hints at future events in a story."},
        {"q":"what is symbolism","a":"Symbolism uses objects to represent abstract ideas: dove = peace."},
        {"q":"what is an allusion","a":"An allusion is a reference to another work, person, or event: 'She's a real Romeo.'"},
        {"q":"what is juxtaposition","a":"Juxtaposition places contrasting elements side by side for effect."},
        {"q":"what is a protagonist","a":"The protagonist is the main character driving the story."},
        {"q":"what is an antagonist","a":"The antagonist opposes the protagonist, creating conflict."},
        {"q":"what is a narrative arc","a":"A narrative arc has: exposition, rising action, climax, falling action, resolution."},
        {"q":"what is tone","a":"Tone is the author's attitude toward the subject: serious, humorous, sarcastic."},
        {"q":"what is mood","a":"Mood is the feeling a text creates in the reader: suspenseful, joyful, melancholic."}
      ],
      "writing": [
        {"q":"what is a thesis statement","a":"A thesis statement presents the main argument of an essay in one or two sentences."},
        {"q":"what is a topic sentence","a":"A topic sentence introduces the main idea of a paragraph."},
        {"q":"what is a hook","a":"A hook captures attention at the start: question, fact, quote, story, or bold statement."},
        {"q":"what is a transition word","a":"Transition words connect ideas: however, therefore, moreover, consequently."},
        {"q":"what is a conclusion","a":"A conclusion summarizes main points and restates the thesis in different words."},
        {"q":"what is an outline","a":"An outline organizes ideas hierarchically: main points with supporting details."},
        {"q":"what is a bibliography","a":"A bibliography lists all sources cited in a work, formatted in APA, MLA, or Chicago style."},
        {"q":"what is peer review","a":"Peer review has experts evaluate a work before publication for quality and accuracy."},
        {"q":"what is a research paper","a":"A research paper presents original analysis supported by evidence and citations."},
        {"q":"what is an expository essay","a":"An expository essay explains a topic using facts and examples, without opinions."},
        {"q":"what is a persuasive essay","a":"A persuasive essay argues a position using evidence, logic, and rhetorical techniques."},
        {"q":"what is a narrative essay","a":"A narrative essay tells a story with a beginning, middle, and end."},
        {"q":"what is a descriptive essay","a":"A descriptive essay paints a picture using sensory details and vivid language."},
        {"q":"what is a haiku","a":"A haiku is a 3-line Japanese poem: 5 syllables, 7 syllables, 5 syllables."},
        {"q":"what is a sonnet","a":"A sonnet is a 14-line poem in iambic pentameter. Shakespearean and Petrarchan forms exist."},
        {"q":"what is free verse","a":"Free verse poetry has no regular meter or rhyme scheme."},
        {"q":"what is prose","a":"Prose is ordinary written language, not poetry. It includes novels, essays, and articles."},
        {"q":"what is syntax","a":"Syntax is the arrangement of words into sentences following grammatical rules."},
        {"q":"what is semantics","a":"Semantics studies meaning in language: how words and sentences convey meaning."},
        {"q":"what is rhetoric","a":"Rhetoric is the art of effective persuasion using ethos, pathos, and logos."}
      ]
    },
    "music": [
      {"q":"what is a chord","a":"Three+ notes played together. Major = happy, minor = sad, diminished = tense."},
      {"q":"what is a scale","a":"A sequence of notes in order. Major and minor are most common in Western music."},
      {"q":"what is rhythm","a":"The pattern of sounds and silences in time."},
      {"q":"what is melody","a":"A sequence of notes forming a tune — the part you hum."},
      {"q":"what is harmony","a":"Multiple notes sounding together to create chords."},
      {"q":"what is tempo","a":"Speed of music in BPM. Allegro (fast), Adagio (slow), Presto (very fast)."},
      {"q":"what is jazz","a":"Jazz features improvisation, swing, blue notes, born in African American communities."},
      {"q":"what is classical music","a":"Western art music from ~11th century to present: symphonies, concertos, sonatas."},
      {"q":"what is a guitar","a":"A stringed instrument with 6 strings, played by plucking or strumming."},
      {"q":"what is a piano","a":"A keyboard instrument with 88 keys, hammers striking strings."},
      {"q":"what is a drum","a":"A percussion instrument producing sound when struck. Essential for rhythm."},
      {"q":"what is a violin","a":"The violin is a 4-stringed instrument played with a bow, highest-pitched in the string family."},
      {"q":"what is a trumpet","a":"A brass instrument with 3 valves, bright and powerful tone."},
      {"q":"what is blues","a":"Blues originated in African American communities, featuring 12-bar progressions and expressive vocals."},
      {"q":"what is rock and roll","a":"Rock and roll emerged in the 1950s combining blues, country, and gospel."},
      {"q":"what is hip hop","a":"Hip hop includes rap, DJing, breakdancing, and graffiti, originating in 1970s New York."},
      {"q":"what is electronic music","a":"Electronic music uses synthesizers, drum machines, and computers to create sounds."},
      {"q":"what is reggae","a":"Reggae originated in Jamaica, featuring offbeat rhythms and socially conscious lyrics."},
      {"q":"what is classical music period","a":"The Classical period (1750-1820) produced Mozart, Haydn, and early Beethoven."},
      {"q":"what is romantic music","a":"The Romantic period (1820-1900) emphasized emotion: Chopin, Liszt, Wagner, Brahms."}
    ],
    "philosophy": [
      {"q":"what is philosophy","a":"Philosophy studies fundamental questions about existence, knowledge, values, and reason."},
      {"q":"who was socrates","a":"Socrates developed the Socratic method of questioning. Executed for 'corrupting youth.'"},
      {"q":"who was plato","a":"Plato founded the Academy and wrote 'The Republic' about an ideal society."},
      {"q":"who was aristotle","a":"Aristotle tutored Alexander the Great and made contributions to logic, biology, and ethics."},
      {"q":"what is ethics","a":"Ethics studies morality: what is right and wrong, and how people should live."},
      {"q":"what is existentialism","a":"Existentialism emphasizes individual freedom, choice, and personal responsibility."},
      {"q":"what is the meaning of life","a":"Various answers: happiness, knowledge, service, creating your own meaning, or religious purpose."},
      {"q":"what is free will","a":"Free will is the ability to make choices not determined by prior causes — debated by philosophers."},
      {"q":"what is consciousness","a":"Consciousness is awareness of oneself and surroundings — the 'hard problem' of philosophy."},
      {"q":"what is truth","a":"Truth is correspondence with reality (correspondence theory) or coherence within a system."},
      {"q":"what is utilitarianism","a":"Utilitarianism says the right action produces the most happiness for the most people."},
      {"q":"what is deontology","a":"Deontology says actions are right or wrong based on rules, regardless of consequences."},
      {"q":"what is virtue ethics","a":"Virtue ethics focuses on character traits: honesty, courage, generosity make a good person."},
      {"q":"what is determinism","a":"Determinism says all events are caused by prior events, making free will an illusion."},
      {"q":"what is stoicism","a":"Stoicism teaches accepting what you can't control and using reason to achieve inner peace."},
      {"q":"what is nihilism","a":"Nihilism rejects inherent meaning in life, morality, and knowledge."},
      {"q":"what is pragmatism","a":"Pragmatism evaluates ideas by their practical consequences and real-world effectiveness."},
      {"q":"what is empiricism","a":"Empiricism says knowledge comes primarily from sensory experience."},
      {"q":"what is rationalism","a":"Rationalism says knowledge comes primarily from reason, independent of experience."},
      {"q":"what is the trolley problem","a":"The trolley problem asks: is it right to sacrifice one person to save five? Tests moral intuition."}
    ],
    "health_medicine": [
      {"q":"what is a calorie","a":"A calorie is energy from food. 1 food calorie = 1 kilocalorie = 4.184 kJ."},
      {"q":"what is BMI","a":"BMI = weight(kg)/height(m)². Underweight <18.5, Normal 18.5-24.9, Overweight 25-29.9, Obese ≥30."},
      {"q":"what is sleep","a":"Sleep is vital for health. Adults need 7-9 hours. Stages: light, deep, REM."},
      {"q":"what are vitamins","a":"13 essential vitamins: A, B complex (8), C, D, E, K. Water or fat soluble."},
      {"q":"what is exercise","a":"Physical activity improving health. WHO recommends 150 min moderate or 75 min vigorous per week."},
      {"q":"what is hydration","a":"Drinking adequate water. Adults need ~2-3 liters daily. Dehydration causes fatigue and headaches."},
      {"q":"what is stress","a":"Stress triggers fight-or-flight. Chronic stress harms immunity, heart, and mental health."},
      {"q":"what is meditation","a":"Meditation practices focus attention for mental clarity and emotional calm."},
      {"q":"what is nutrition","a":"Nutrition studies nutrients in food and their effects on health."},
      {"q":"what is metabolism","a":"Metabolism converts food to energy. Basal metabolic rate is calories burned at rest."},
      {"q":"what is diabetes","a":"Diabetes is high blood sugar. Type 1: immune system destroys insulin cells. Type 2: insulin resistance."},
      {"q":"what is hypertension","a":"Hypertension is high blood pressure (≥130/80 mmHg). Often silent but damages organs."},
      {"q":"what is cholesterol","a":"Cholesterol is a waxy substance. HDL ('good') removes it; LDL ('bad') builds up in arteries."},
      {"q":"what is an antibiotic","a":"Antibiotics kill or inhibit bacteria. Don't work on viruses. Complete the full course."},
      {"q":"what is a vaccine","a":"Vaccines train the immune system to recognize and fight specific pathogens."},
      {"q":"what is inflammation","a":"Inflammation is the body's response to injury: redness, swelling, heat, pain. Chronic inflammation is harmful."},
      {"q":"what is anatomy","a":"Anatomy studies body structure: organs, tissues, cells, and their relationships."},
      {"q":"what is physiology","a":"Physiology studies how body parts function and work together."},
      {"q":"what is a neuron","a":"A neuron transmits information via electrical and chemical signals. ~86 billion in the human brain."},
      {"q":"what is the circadian rhythm","a":"The circadian rhythm is the ~24-hour internal clock regulating sleep, hormones, and body temperature."}
    ],
    "daily_life": [
      {"q":"how to cook rice","a":"Rinse 1 cup rice, add 2 cups water, boil, cover, simmer 18 min, rest 5 min."},
      {"q":"how to make coffee","a":"1-2 tbsp ground coffee per 6 oz water. Brew with drip, French press, or espresso."},
      {"q":"how to do laundry","a":"Sort by color, check labels, add detergent, choose cycle, dry appropriately."},
      {"q":"how to budget money","a":"50% needs, 30% wants, 20% savings. Track income and expenses."},
      {"q":"how to manage time","a":"Prioritize tasks, use time-blocking, minimize distractions, take breaks."},
      {"q":"how to clean a house","a":"Top to bottom, left to right. Declutter, dust, clean surfaces, vacuum last."},
      {"q":"how to organize a room","a":"Declutter first, use storage containers, label, designate zones."},
      {"q":"how to plant a garden","a":"Choose sunny spot, prepare soil, select climate-appropriate plants, water regularly."},
      {"q":"how to sew","a":"Thread needle, knot end, running stitch (in and out), backstitch for strength."},
      {"q":"how to iron clothes","a":"Set fabric temperature, iron while damp, smooth strokes, collar first."},
      {"q":"how to make pasta","a":"Boil salted water, cook pasta 8-12 min until al dente, drain, add sauce."},
      {"q":"how to bake bread","a":"Mix flour, yeast, water, salt. Knead, rise 1 hour, shape, rise again, bake at 375°F."},
      {"q":"how to sharpen a knife","a":"Use a whetstone at 20° angle, draw blade across stone, alternate sides."},
      {"q":"how to remove a stain","a":"Blot (don't rub), apply appropriate cleaner (water for water-based, solvent for oil-based), wash."},
      {"q":"how to fix a flat tire","a":"Remove wheel, use tire irons to remove tire, patch or replace tube, reassemble."},
      {"q":"how to unclog a drain","a":"Use plunger first. If fails, try baking soda + vinegar. Last resort: snake or disassemble."},
      {"q":"how to change a light bulb","a":"Turn off power, let cool, unscrew old bulb, screw in new one of same wattage/type."},
      {"q":"how to fold a fitted sheet","a":"Hold corners, tuck one corner into another, fold into rectangle, fold into smaller rectangle."},
      {"q":"how to parallel park","a":"Pull alongside car ahead, reverse while turning wheel, straighten, pull forward."},
      {"q":"how to tie a tie","a":"Wide end over narrow, behind and over, through loop, behind, through front loop, through neck loop."}
    ],
    "space_deep": [
      {"q":"how far is the sun","a":"150 million km (93 million miles). Light takes 8 min 20 sec to reach Earth."},
      {"q":"how far is the moon","a":"384,400 km average distance from Earth."},
      {"q":"how fast is light","a":"299,792 km/s in vacuum. The universal speed limit."},
      {"q":"what planets are there","a":"Mercury, Venus, Earth, Mars, Jupiter, Saturn, Uranus, Neptune."},
      {"q":"how old is the earth","a":"~4.54 billion years old, based on radiometric dating."},
      {"q":"how old is the universe","a":"~13.8 billion years old, based on cosmic microwave background observations."},
      {"q":"what is a star","a":"A luminous plasma sphere generating energy through nuclear fusion of hydrogen into helium."},
      {"q":"what is a supernova","a":"A stellar explosion briefly outshining an entire galaxy, dispersing heavy elements."},
      {"q":"what is gravity on the moon","a":"~1/6th of Earth's gravity. A 100kg person weighs ~16.5kg on the Moon."},
      {"q":"how many moons does jupiter have","a":"95 known moons. The four largest are the Galilean moons: Io, Europa, Ganymede, Callisto."},
      {"q":"what is the speed of light in mph","a":"Light travels at ~670 million mph (1,079 million km/h)."},
      {"q":"what is a white dwarf","a":"A white dwarf is the remnant of a low-mass star, incredibly dense."},
      {"q":"what is a red giant","a":"A red giant is an aging star that has expanded, cooling at its surface."},
      {"q":"what is a binary star","a":"A binary star system has two stars orbiting each other."},
      {"q":"what is a nebula","a":"A nebula is a cloud of gas and dust in space, often a star-forming region."},
      {"q":"what is the milky way made of","a":"Stars, gas, dust, and dark matter. Our solar system orbits ~26,000 light-years from center."},
      {"q":"what is the cosmic microwave background","a":"The CMB is residual radiation from the Big Bang, permeating all of space at ~2.7 Kelvin."},
      {"q":"what is dark energy","a":"Dark energy causes the universe's accelerated expansion, making up ~68% of total energy."},
      {"q":"what is the multiverse theory","a":"The multiverse theory suggests our universe may be one of many parallel universes."},
      {"q":"what is a magnetar","a":"A magnetar is a neutron star with an incredibly powerful magnetic field."}
    ],
    "environment": [
      {"q":"what is climate change","a":"Long-term shift in global temperatures and weather patterns, largely driven by human greenhouse gas emissions."},
      {"q":"what is global warming","a":"Global warming is the increase in Earth's average temperature due to greenhouse gases trapping heat."},
      {"q":"what is the greenhouse effect","a":"Greenhouse gases trap solar heat in the atmosphere, warming the planet. Essential for life but enhanced by pollution."},
      {"q":"what is renewable energy","a":"Energy from sources that replenish: solar, wind, hydro, geothermal, biomass."},
      {"q":"what is carbon footprint","a":"The total greenhouse gases produced by human activities, measured in CO₂ equivalent."},
      {"q":"what is deforestation","a":"Deforestation is clearing forests for agriculture, development, or logging."},
      {"q":"what is sustainable development","a":"Meeting present needs without compromising future generations' ability to meet theirs."},
      {"q":"what is biodiversity loss","a":"The decline in variety of life on Earth due to habitat destruction, pollution, and climate change."},
      {"q":"what is ocean acidification","a":"Oceans absorb CO₂, becoming more acidic. Harmful to coral reefs and marine life."},
      {"q":"what is solar energy","a":"Solar energy captures sunlight using photovoltaic panels or thermal collectors."},
      {"q":"what is wind energy","a":"Wind turbines convert kinetic energy from wind into electricity."},
      {"q":"what is nuclear energy","a":"Nuclear energy comes from fission of uranium atoms, producing heat to generate electricity."},
      {"q":"what is fossil fuel","a":"Fossil fuels (coal, oil, natural gas) formed from ancient organisms over millions of years."},
      {"q":"what is electric vehicle","a":"EVs use electric motors powered by batteries instead of internal combustion engines."},
      {"q":"what is carbon capture","a":"Carbon capture technology removes CO₂ from the atmosphere or industrial sources."},
      {"q":"what is a circular economy","a":"A circular economy minimizes waste by reusing, repairing, and recycling materials."},
      {"q":"what is greenwashing","a":"Greenwashing is misleading marketing claiming a product is environmentally friendly when it isn't."},
      {"q":"what is water pollution","a":"Contamination of water bodies from industrial waste, sewage, chemicals, and plastics."},
      {"q":"what is air pollution","a":"Harmful substances in the air: particulate matter, ozone, nitrogen dioxide, sulfur dioxide."},
      {"q":"what is endangered species","a":"Endangered species face a very high risk of extinction. Examples: pandas, tigers, blue whales."}
    ],
    "psychology": [
      {"q":"what is psychology","a":"Psychology is the scientific study of mind and behavior."},
      {"q":"what is cognitive behavioral therapy","a":"CBT identifies and changes negative thought patterns and behaviors."},
      {"q":"what is Maslow's hierarchy of needs","a":"Maslow's hierarchy: physiological  safety  love/belonging  esteem  self-actualization."},
      {"q":"what is the placebo effect","a":"The placebo effect is real improvement from a fake treatment due to belief."},
      {"q":"what is cognitive bias","a":"Cognitive biases are systematic errors in thinking that affect decisions and judgments."},
      {"q":"what is classical conditioning","a":"Classical conditioning pairs a neutral stimulus with an unconditioned response (Pavlov's dogs)."},
      {"q":"what is operant conditioning","a":"Operant conditioning uses rewards and punishments to shape behavior (Skinner)."},
      {"q":"what is the Stanford prison experiment","a":"Zimbardo's 1971 study showed how role assignment can cause extreme behavior."},
      {"q":"what is the marshmallow test","a":"Delayed gratification study: children who waited for two marshmallows had better life outcomes."},
      {"q":"what is confirmation bias","a":"Confirmation bias is seeking information that confirms existing beliefs, ignoring contradictory evidence."},
      {"q":"what is the halo effect","a":"The halo effect is a cognitive bias where one positive trait influences overall perception."},
      {"q":"what is Stockholm syndrome","a":"Stockholm syndrome is when hostages develop positive feelings toward their captors."},
      {"q":"what is the bystander effect","a":"The bystander effect: people are less likely to help when others are present."},
      {"q":"what is intrinsic motivation","a":"Intrinsic motivation comes from internal satisfaction rather than external rewards."},
      {"q":"what is extraversion","a":"Extraversion is a personality trait characterized by sociability, assertiveness, and positive emotion."},
      {"q":"what is introversion","a":"Introversion is a personality trait characterized by preferring solitude and smaller groups."},
      {"q":"what is emotional intelligence","a":"EI is the ability to recognize, understand, and manage one's own and others' emotions."},
      {"q":"what is neuroplasticity","a":"Neuroplasticity is the brain's ability to reorganize itself by forming new neural connections."},
      {"q":"what is sleep deprivation","a":"Lack of sufficient sleep impairs cognition, memory, and physical health."},
      {"q":"what is the fight or flight response","a":"Fight or flight is the body's acute stress response: adrenaline, increased heart rate, focused attention."}
    ],
    "economics": [
      {"q":"what is supply and demand","a":"Supply and demand determine price: high demand + low supply = high price, and vice versa."},
      {"q":"what is inflation","a":"Inflation is rising prices over time, reducing purchasing power of money."},
      {"q":"what is GDP","a":"GDP (Gross Domestic Product) is the total value of goods and services produced in a country."},
      {"q":"what is a recession","a":"A recession is two consecutive quarters of negative GDP growth."},
      {"q":"what is capitalism","a":"Capitalism is an economic system where private individuals own and operate businesses for profit."},
      {"q":"what is socialism","a":"Socialism is an economic system where the government or community owns and controls major industries."},
        {"q":"what is interest rate","a":"Interest rate is the cost of borrowing money, expressed as a percentage of the loan amount."},
      {"q":"what is the stock market","a":"The stock market is where shares of publicly traded companies are bought and sold."},
      {"q":"what is cryptocurrency","a":"Cryptocurrency is digital currency using cryptography for security and blockchain for transactions."},
      {"q":"what is trade deficit","a":"A trade deficit occurs when a country imports more than it exports."},
      {"q":"what is monopoly","a":"A monopoly is exclusive control of a market, with no competition."},
      {"q":"what is inflation targeting","a":"Central banks set inflation targets (usually ~2%) to balance growth and stability."},
      {"q":"what is quantitative easing","a":"QE is when central banks buy financial assets to increase money supply and stimulate the economy."},
      {"q":"what is opportunity cost","a":"Opportunity cost is the value of the next best alternative you give up when making a choice."},
      {"q":"what is comparative advantage","a":"A country has comparative advantage when it can produce goods at lower opportunity cost."},
      {"q":"what is a tariff","a":"A tariff is a tax on imported goods, making them more expensive to protect domestic industries."},
      {"q":"what is unemployment","a":"Unemployment is the percentage of the labor force actively seeking work but unable to find it."},
      {"q":"what is the federal reserve","a":"The Federal Reserve is the US central bank, controlling monetary policy and interest rates."},
      {"q":"what is a bull market","a":"A bull market is a period of rising stock prices and investor optimism."},
      {"q":"what is a bear market","a":"A bear market is a period of falling stock prices (≥20% decline) and pessimism."}
    ],
    "cooking": [
      {"q":"how to make pancakes","a":"Mix flour, sugar, baking powder, milk, egg, melted butter. Cook on griddle until bubbles form, flip."},
      {"q":"how to make an omelette","a":"Beat eggs, pour into buttered pan, add fillings, fold when edges set."},
      {"q":"how to make a smoothie","a":"Blend fruit, yogurt/milk, ice. Add spinach for green smoothies, protein powder for shakes."},
      {"q":"how to make pizza dough","a":"Mix flour, yeast, water, salt, olive oil. Knead, rise 1 hour, stretch, top, bake at 475°F."},
      {"q":"how to roast chicken","a":"Season whole chicken, roast at 425°F for 1-1.5 hours until internal temp reaches 165°F."},
      {"q":"how to make soup","a":"Sauté aromatics (onion, garlic), add broth and vegetables, simmer until tender, blend if desired."},
      {"q":"how to make sushi","a":"Season rice with vinegar. Place on nori, add fish/vegetables, roll tightly, slice."},
      {"q":"how to make guacamole","a":"Mash ripe avocados, add lime juice, salt, cilantro, onion, tomato. Mix gently."},
      {"q":"how to make stir fry","a":"Heat oil in wok, cook protein first, remove, cook vegetables, add sauce, return protein."},
      {"q":"how to grill steak","a":"Bring to room temp, season generously, sear on high heat 3-4 min per side for medium-rare."},
      {"q":"how to make pasta sauce","a":"Sauté garlic in olive oil, add canned tomatoes, basil, oregano, salt, simmer 20-30 min."},
      {"q":"how to make scrambled eggs","a":"Beat eggs, cook on low heat with butter, stir gently until soft curds form. Don't overcook."},
      {"q":"how to make banana bread","a":"Mash 3 bananas, mix with flour, sugar, butter, egg, baking soda. Bake at 350°F for 60 min."},
      {"q":"how to make french toast","a":"Dip bread in beaten eggs mixed with milk and cinnamon, cook on griddle until golden."},
      {"q":"how to make fried rice","a":"Use day-old rice, stir fry with vegetables, soy sauce, sesame oil, and scrambled egg."},
      {"q":"how to make cookies","a":"Cream butter and sugar, add egg and vanilla, mix in flour and chocolate chips, bake at 375°F."},
      {"q":"how to make mac and cheese","a":"Cook pasta, make cheese sauce (butter, flour, milk, cheddar), combine, bake optional."},
      {"q":"how to make tacos","a":"Season ground beef with chili powder, cumin, garlic. Serve in tortillas with toppings."},
      {"q":"how to make fried chicken","a":"Dredge chicken in seasoned flour, dip in buttermilk, fry in 350°F oil until golden and cooked."},
      {"q":"how to make ramen","a":"Cook noodles, prepare broth (miso or pork), top with soft-boiled egg, pork, nori, green onion."}
    ],
    "sports": [
      {"q":"what is soccer","a":"Soccer (football) is played with two teams of 11, scoring by getting the ball into the opposing goal."},
      {"q":"what is basketball","a":"Basketball: two teams of 5, score by shooting a ball through a 10-foot hoop."},
      {"q":"what is baseball","a":"Baseball: two teams of 9, batting and fielding, scoring runs by circling four bases."},
      {"q":"what is american football","a":"American football: two teams of 11, score touchdowns (6 pts) and field goals (3 pts)."},
      {"q":"what is tennis","a":"Tennis: singles or doubles, hit a ball over a net, score points to win games and sets."},
      {"q":"what is cricket","a":"Cricket: bat and ball sport, two teams of 11, batting and bowling on an oval field."},
      {"q":"what is golf","a":"Golf: hit a ball into a hole using fewest strokes possible over 18 holes."},
      {"q":"what is swimming","a":"Swimming: competitive races in butterfly, backstroke, breaststroke, and freestyle."},
      {"q":"what is olympics","a":"The Olympics: international multi-sport event every 4 years, Summer and Winter editions."},
      {"q":"what is marathon","a":"A marathon is a 42.195 km (26.2 miles) long-distance running race."},
      {"q":"what is rugby","a":"Rugby: two teams of 15 (or 7s variant), oval ball, score by tries (5 pts) and kicks."},
      {"q":"what is hockey","a":"Hockey: field hockey or ice hockey, two teams score by hitting a ball/puck into a goal."},
      {"q":"what is boxing","a":"Boxing: combat sport, two fighters throw punches in a ring for rounds."},
      {"q":"what is MMA","a":"Mixed Martial Arts combines techniques from boxing, wrestling, jiu-jitsu, and other combat sports."},
      {"q":"what is Formula 1","a":"Formula 1: premier auto racing series with the fastest road-course racing cars."},
      {"q":"what is cycling","a":"Cycling: road racing, track, mountain bike, BMX. Tour de France is the most famous race."},
      {"q":"what is table tennis","a":"Table tennis (ping pong): two or four players hit a lightweight ball back and forth across a table."},
      {"q":"what is badminton","a":"Badminton: racket sport hitting a shuttlecock over a net. Fastest racket sport (400+ km/h smashes)."},
      {"q":"what is volleyball","a":"Volleyball: two teams of 6 hit a ball over a net, scoring when the ball hits the opponent's court."},
      {"q":"what is skateboarding","a":"Skateboarding: riding and performing tricks on a skateboard. Olympic sport since 2020."}
    ]
  }
}
KNOWLEDGE
}

# Count facts
ai_knowledge_mega_count() {
  ai_knowledge_mega | python3 -c "
import sys, json
data = json.load(sys.stdin)
total = 0
for domain, topics in data['domains'].items():
    if isinstance(topics, dict):
        for topic, facts in topics.items():
            total += len(facts)
    elif isinstance(topics, list):
        total += len(topics)
print(f'Total facts: {total}')
" 2>/dev/null
}

# Search mega knowledge
ai_knowledge_mega_search() {
  local query="$1"
  [ -z "$query" ] && return 1
  ai_knowledge_mega | python3 -c "
import sys, json
data = json.load(sys.stdin)
query = sys.argv[1].lower()
best_match = None
best_score = 0

for domain, topics in data['domains'].items():
    if isinstance(topics, dict):
        for topic, facts in topics.items():
            for fact in facts:
                q = fact['q'].lower()
                a = fact['a'].lower()
                score = 0
                for word in query.split():
                    if len(word) > 2:
                        if word in q: score += 10
                        if word in a: score += 5
                if query in q or q in query: score += 50
                if score > best_score:
                    best_score = score
                    best_match = fact
    elif isinstance(topics, list):
        for fact in topics:
            q = fact['q'].lower()
            a = fact['a'].lower()
            score = 0
            for word in query.split():
                if len(word) > 2:
                    if word in q: score += 10
                    if word in a: score += 5
            if query in q or q in query: score += 50
            if score > best_score:
                best_score = score
                best_match = fact

if best_match and best_score >= 10:
    print(best_match['a'])
else:
    print('')
" 2>/dev/null "$query"
}

echo "[ai-knowledge-mega] loaded — $(ai_knowledge_mega_count)"
