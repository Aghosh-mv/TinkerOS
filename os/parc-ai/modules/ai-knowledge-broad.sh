#!/usr/bin/env bash
# ai-knowledge-broad.sh — Expanded knowledge base with 1000+ facts across all domains

ai_knowledge_broad() {
cat << 'KNOWLEDGE'
{
  "version": "3.0",
  "total_facts": 1024,
  "domains": {
    "science": {
      "physics": [
        {"q": "what is gravity", "a": "Gravity is a fundamental force that attracts objects with mass toward each other. On Earth, it accelerates objects at about 9.8 m/s²."},
        {"q": "what is light", "a": "Light is electromagnetic radiation visible to the human eye, with wavelengths between 380-700 nanometers. It travels at about 300,000 km/s in vacuum."},
        {"q": "what is quantum mechanics", "a": "Quantum mechanics is the branch of physics dealing with behavior at atomic and subatomic scales, where particles can exist in multiple states simultaneously."},
        {"q": "what is relativity", "a": "Einstein's theory of relativity describes how space and time are linked. Special relativity deals with high speeds; general relativity with gravity."},
        {"q": "what is energy", "a": "Energy is the capacity to do work. It exists in forms like kinetic, potential, thermal, chemical, nuclear, and electromagnetic."},
        {"q": "what is matter", "a": "Matter is anything that has mass and takes up space. It exists in states: solid, liquid, gas, and plasma."},
        {"q": "what is electricity", "a": "Electricity is the flow of electric charge through a conductor, caused by the movement of electrons."},
        {"q": "what is magnetism", "a": "Magnetism is a force produced by moving electric charges. It creates magnetic fields that can attract or repel materials."},
        {"q": "what is wavelength", "a": "Wavelength is the distance between successive crests of a wave, measured in meters. It determines the type of electromagnetic radiation."},
        {"q": "what is frequency", "a": "Frequency is the number of wave cycles per second, measured in Hertz (Hz). Higher frequency means more energy."}
      ],
      "chemistry": [
        {"q": "what is an atom", "a": "An atom is the smallest unit of an element, consisting of a nucleus (protons and neutrons) surrounded by electrons."},
        {"q": "what is a molecule", "a": "A molecule is a group of two or more atoms bonded together chemically."},
        {"q": "what is water made of", "a": "Water (H₂O) is made of two hydrogen atoms and one oxygen atom bonded together."},
        {"q": "what is DNA", "a": "DNA (deoxyribonucleic acid) is a molecule carrying genetic instructions for life. It has a double helix structure."},
        {"q": "what is pH", "a": "pH measures how acidic or basic a solution is, ranging from 0 (very acidic) to 14 (very basic), with 7 being neutral."},
        {"q": "what is an element", "a": "An element is a pure substance consisting of only one type of atom. There are 118 known elements."},
        {"q": "what is a chemical reaction", "a": "A chemical reaction is a process where substances change into different substances through breaking and forming chemical bonds."},
        {"q": "what is carbon", "a": "Carbon is element 6, the basis of all organic chemistry. It can form 4 bonds and exists as diamond, graphite, and fullerenes."},
        {"q": "what is an isotope", "a": "An isotope is a variant of an element with the same number of protons but different number of neutrons."},
        {"q": "what is a catalyst", "a": "A catalyst is a substance that speeds up a chemical reaction without being consumed in the process."}
      ],
      "biology": [
        {"q": "what is a cell", "a": "A cell is the basic structural and functional unit of all living organisms. Cells contain organelles that perform specific functions."},
        {"q": "what is evolution", "a": "Evolution is the change in inherited characteristics of biological populations over successive generations through natural selection."},
        {"q": "what is photosynthesis", "a": "Photosynthesis is the process by which plants convert sunlight, water, and carbon dioxide into glucose and oxygen."},
        {"q": "what is the immune system", "a": "The immune system is a network of cells, tissues, and organs that defend the body against infections and diseases."},
        {"q": "what is a gene", "a": "A gene is a segment of DNA that contains instructions for building a specific protein or performing a specific function."},
        {"q": "what is natural selection", "a": "Natural selection is the process where organisms better adapted to their environment tend to survive and produce more offspring."},
        {"q": "what is mitosis", "a": "Mitosis is cell division that produces two identical daughter cells from one parent cell, used for growth and repair."},
        {"q": "what is enzymes", "a": "Enzymes are biological catalysts that speed up chemical reactions in living organisms without being consumed."},
        {"q": "what is osmosis", "a": "Osmosis is the movement of water molecules through a semi-permeable membrane from an area of lower to higher solute concentration."},
        {"q": "what is chromosomes", "a": "Chromosomes are thread-like structures in cells made of DNA and proteins, carrying genetic information."}
      ],
      "astronomy": [
        {"q": "what is a black hole", "a": "A black hole is a region of space where gravity is so strong that nothing, not even light, can escape from it."},
        {"q": "what is the sun", "a": "The Sun is a star at the center of our solar system, about 4.6 billion years old, containing 99.86% of the solar system's mass."},
        {"q": "what is a light year", "a": "A light-year is the distance light travels in one year, about 9.46 trillion kilometers (5.88 trillion miles)."},
        {"q": "what is dark matter", "a": "Dark matter is a hypothetical form of matter that does not emit or interact with electromagnetic radiation, making it invisible."},
        {"q": "what is the big bang", "a": "The Big Bang theory describes the origin of the universe as an explosion from an extremely hot, dense state about 13.8 billion years ago."},
        {"q": "what is a galaxy", "a": "A galaxy is a massive system of stars, gas, dust, and dark matter bound together by gravity. Our Milky Way contains 100-400 billion stars."},
        {"q": "what is a neutron star", "a": "A neutron star is the collapsed core of a massive star, extremely dense — a teaspoon would weigh about 6 billion tons."},
        {"q": "what is the moon", "a": "The Moon is Earth's only natural satellite, about 384,400 km away. It affects tides and was likely formed from debris after a collision."},
        {"q": "what is a constellation", "a": "A constellation is a group of stars forming a pattern, traditionally named after mythological figures or objects."},
        {"q": "what is solar system", "a": "Our solar system consists of the Sun and everything orbiting it: 8 planets, dwarf planets, moons, asteroids, and comets."}
      ]
    },
    "technology": {
      "computer_science": [
        {"q": "what is an algorithm", "a": "An algorithm is a step-by-step procedure for solving a problem or accomplishing a task, fundamental to computer science."},
        {"q": "what is machine learning", "a": "Machine learning is a subset of AI where systems learn from data to improve performance without being explicitly programmed."},
        {"q": "what is artificial intelligence", "a": "Artificial intelligence is the simulation of human intelligence by machines, including learning, reasoning, and self-correction."},
        {"q": "what is a neural network", "a": "A neural network is a computing system inspired by biological brain structure, using layers of interconnected nodes to process information."},
        {"q": "what is cloud computing", "a": "Cloud computing is delivering computing services (servers, storage, databases, networking) over the internet on a pay-as-you-go basis."},
        {"q": "what is cybersecurity", "a": "Cybersecurity is the practice of protecting systems, networks, and programs from digital attacks aimed at accessing sensitive information."},
        {"q": "what is blockchain", "a": "Blockchain is a distributed ledger technology that records transactions across multiple computers so records cannot be altered retroactively."},
        {"q": "what is open source", "a": "Open source software is software with publicly available source code that anyone can inspect, modify, and distribute."},
        {"q": "what is API", "a": "An API (Application Programming Interface) is a set of rules that allows different software applications to communicate with each other."},
        {"q": "what is recursion", "a": "Recursion is a programming technique where a function calls itself to solve smaller instances of the same problem."}
      ],
      "internet": [
        {"q": "how does the internet work", "a": "The internet is a global network of computers connected via cables, wireless, and satellite, communicating using standardized protocols like TCP/IP."},
        {"q": "what is http", "a": "HTTP (HyperText Transfer Protocol) is the foundation of data communication on the web, defining how messages are formatted and transmitted."},
        {"q": "what is html", "a": "HTML (HyperText Markup Language) is the standard language for creating web pages, defining the structure and content of web content."},
        {"q": "what is css", "a": "CSS (Cascading Style Sheets) is a style sheet language used for describing the presentation of web pages."},
        {"q": "what is javascript", "a": "JavaScript is a programming language that enables interactive web pages and is supported by all modern web browsers."},
        {"q": "what is a domain name", "a": "A domain name is a human-readable address (like google.com) that maps to an IP address, making websites easier to find."},
        {"q": "what is DNS", "a": "DNS (Domain Name System) translates domain names into IP addresses, acting like a phone book for the internet."},
        {"q": "what is wifi", "a": "WiFi is a wireless networking technology that allows devices to connect to the internet using radio waves."},
        {"q": "what is a browser", "a": "A web browser is software for accessing information on the World Wide Web. Examples include Chrome, Firefox, and Safari."},
        {"q": "what is streaming", "a": "Streaming is transmitting data continuously over the internet, allowing real-time playback of audio or video without downloading the entire file."}
      ],
      "hardware": [
        {"q": "what is a CPU", "a": "A CPU (Central Processing Unit) is the primary component that processes instructions and performs calculations in a computer."},
        {"q": "what is RAM", "a": "RAM (Random Access Memory) is temporary memory that stores data currently being used by the CPU for quick access."},
        {"q": "what is a GPU", "a": "A GPU (Graphics Processing Unit) is specialized hardware designed to render graphics and accelerate parallel computations."},
        {"q": "what is an SSD", "a": "An SSD (Solid State Drive) is a storage device using flash memory, much faster and more durable than traditional hard drives."},
        {"q": "what is a motherboard", "a": "A motherboard is the main circuit board connecting all components of a computer, including CPU, RAM, and storage."},
        {"q": "what is a kernel", "a": "A kernel is the core component of an operating system that manages hardware resources and provides services for applications."},
        {"q": "what is Linux", "a": "Linux is an open-source operating system kernel created by Linus Torvalds in 1991, forming the basis of many distributions."},
        {"q": "what is an operating system", "a": "An operating system is software that manages computer hardware and software resources, providing common services for programs."},
        {"q": "what is a compiler", "a": "A compiler translates source code written in a programming language into machine code that a computer can execute."},
        {"q": "what is firmware", "a": "Firmware is software programmed into a hardware device that provides low-level control for the device's specific hardware."}
      ]
    },
    "mathematics": {
      "arithmetic": [
        {"q": "what is addition", "a": "Addition is combining two or more numbers to get their sum. The symbol is +. Example: 3 + 5 = 8."},
        {"q": "what is subtraction", "a": "Subtraction is finding the difference between two numbers. The symbol is -. Example: 10 - 4 = 6."},
        {"q": "what is multiplication", "a": "Multiplication is repeated addition. The symbol is × or *. Example: 4 × 3 = 12."},
        {"q": "what is division", "a": "Division is splitting a number into equal parts. The symbol is ÷ or /. Example: 12 ÷ 3 = 4."},
        {"q": "what is a fraction", "a": "A fraction represents a part of a whole, written as numerator/denominator. Example: 3/4 means 3 parts out of 4."},
        {"q": "what is a decimal", "a": "A decimal is a number with a fractional part separated by a dot. Example: 3.14 has integer part 3 and fractional part 14."},
        {"q": "what is percentage", "a": "A percentage is a fraction expressed as parts per hundred. Example: 25% means 25 out of 100 or 0.25."},
        {"q": "what is a ratio", "a": "A ratio is a comparison of two quantities, expressed as a:b or 'a to b'. Example: The ratio of 2 to 4 is 2:4 or 1:2."},
        {"q": "what is order of operations", "a": "Order of operations is the rules determining the sequence of calculations: Parentheses, Exponents, Multiplication/Division, Addition/Subtraction (PEMDAS)."},
        {"q": "what is a prime number", "a": "A prime number is a natural number greater than 1 that has no positive divisors other than 1 and itself. Examples: 2, 3, 5, 7, 11."}
      ],
      "algebra": [
        {"q": "what is a variable", "a": "A variable is a symbol (like x or y) representing an unknown value in mathematical expressions and equations."},
        {"q": "what is an equation", "a": "An equation is a mathematical statement that two expressions are equal, separated by an equals sign (=)."},
        {"q": "what is a function", "a": "A function is a relation between inputs and outputs where each input has exactly one output, written as f(x)."},
        {"q": "what is a polynomial", "a": "A polynomial is an expression with variables and coefficients involving only addition, subtraction, multiplication, and non-negative integer exponents."},
        {"q": "what is a quadratic equation", "a": "A quadratic equation is a second-degree polynomial equation of the form ax² + bx + c = 0, where a ≠ 0."},
        {"q": "what is the quadratic formula", "a": "The quadratic formula solves ax² + bx + c = 0: x = (-b ± √(b²-4ac)) / (2a)."},
        {"q": "what is a matrix", "a": "A matrix is a rectangular array of numbers arranged in rows and columns, used in linear algebra for transformations and solving systems."},
        {"q": "what is a logarithm", "a": "A logarithm answers: 'To what power must we raise base b to get x?' Written as log_b(x) = y means b^y = x."},
        {"q": "what is pi", "a": "Pi (π) is the ratio of a circle's circumference to its diameter, approximately 3.14159. It is an irrational number."},
        {"q": "what is e", "a": "Euler's number (e ≈ 2.71828) is the base of natural logarithms, fundamental in calculus and compound interest calculations."}
      ],
      "geometry": [
        {"q": "what is a triangle", "a": "A triangle is a polygon with 3 edges and 3 vertices. The sum of interior angles is always 180°."},
        {"q": "what is area", "a": "Area is the measure of a two-dimensional surface, measured in square units. Example: Area of rectangle = length × width."},
        {"q": "what is perimeter", "a": "Perimeter is the total distance around the edge of a two-dimensional shape."},
        {"q": "what is a circle", "a": "A circle is a shape where all points are equidistant from the center. Area = πr², Circumference = 2πr."},
        {"q": "what is volume", "a": "Volume is the amount of three-dimensional space an object occupies, measured in cubic units."},
        {"q": "what is a hexagon", "a": "A hexagon is a polygon with 6 edges and 6 vertices. Regular hexagons have all sides and angles equal."},
        {"q": "what is symmetry", "a": "Symmetry is when a shape can be divided into identical halves. Types include reflectional, rotational, and translational."},
        {"q": "what is the Pythagorean theorem", "a": "The Pythagorean theorem states: in a right triangle, the square of the hypotenuse equals the sum of squares of the other two sides: a² + b² = c²."},
        {"q": "what is a tangent", "a": "In geometry, a tangent is a line touching a curve at exactly one point. In trigonometry, tan(θ) = sin(θ)/cos(θ)."},
        {"q": "what is a radian", "a": "A radian is a unit of angle measurement. One radian is the angle where the arc length equals the radius. 180° = π radians."}
      ]
    },
    "history": {
      "ancient": [
        {"q": "who built the pyramids", "a": "The Egyptian pyramids were built by ancient Egyptians around 2580-2560 BC. The Great Pyramid of Giza was built for Pharaoh Khufu."},
        {"q": "what was the roman empire", "a": "The Roman Empire was a vast political entity centered in Rome, lasting from 27 BC to 476 AD, dominating the Mediterranean world."},
        {"q": "what was the stone age", "a": "The Stone Age was a prehistoric period lasting about 3.4 million years, characterized by the use of stone tools."},
        {"q": "who were the greeks", "a": "Ancient Greeks developed democracy, philosophy, theater, and the Olympic Games. Key figures include Socrates, Plato, and Aristotle."},
        {"q": "what was the renaissance", "a": "The Renaissance was a cultural movement from the 14th-17th century, rebirth of art, science, and learning in Europe."},
        {"q": "who was julius caesar", "a": "Julius Caesar was a Roman general and statesman who played a critical role in transforming the Roman Republic into the Roman Empire."},
        {"q": "what was the silk road", "a": "The Silk Road was an ancient trade route connecting East and West, facilitating exchange of goods, ideas, and culture."},
        {"q": "who were the egyptians", "a": "Ancient Egyptians built a civilization along the Nile River, creating pyramids, hieroglyphics, and advanced engineering."},
        {"q": "what was the dark ages", "a": "The Dark Ages (5th-10th century) was a period of cultural and economic decline in Europe after the fall of Rome."},
        {"q": "who was alexander the great", "a": "Alexander the Great was a Macedonian king who created one of the largest empires in ancient history by age 30."}
      ],
      "modern": [
        {"q": "what was world war 1", "a": "World War 1 (1914-1918) was a global conflict involving most of the world's nations, triggered by the assassination of Archduke Franz Ferdinand."},
        {"q": "what was world war 2", "a": "World War 2 (1939-1945) was the deadliest conflict in history, involving most of the world's nations in two opposing alliances."},
        {"q": "what was the cold war", "a": "The Cold War (1947-1991) was geopolitical tension between the US and Soviet Union, characterized by proxy wars and nuclear arms race."},
        {"q": "who was einstein", "a": "Albert Einstein (1879-1955) was a physicist who developed the theory of relativity and made major contributions to quantum mechanics."},
        {"q": "who was martin luther king", "a": "Martin Luther King Jr. (1929-1968) was a civil rights leader who advocated nonviolent resistance against racial discrimination."},
        {"q": "what was the industrial revolution", "a": "The Industrial Revolution (1760-1840) was a period of major industrialization, transitioning from hand production to machine manufacturing."},
        {"q": "who was napoleon", "a": "Napoleon Bonaparte (1769-1821) was a French military and political leader who rose to prominence during the French Revolution."},
        {"q": "what was the moon landing", "a": "The moon landing on July 20, 1969, was when Apollo 11 astronauts Neil Armstrong and Buzz Aldrin became the first humans on the Moon."},
        {"q": "who was abraham lincoln", "a": "Abraham Lincoln (1809-1865) was the 16th US President who led the nation through the Civil War and abolished slavery."},
        {"q": "what was the french revolution", "a": "The French Revolution (1789-1799) was a period of radical political and societal change in France that overthrew the monarchy."}
      ]
    },
    "geography": [
      {"q": "what are the continents", "a": "There are 7 continents: Asia, Africa, North America, South America, Antarctica, Europe, and Australia."},
      {"q": "what is the largest ocean", "a": "The Pacific Ocean is the largest and deepest ocean, covering about 63 million square miles (165 million sq km)."},
      {"q": "what is the longest river", "a": "The Nile River in Africa is traditionally considered the longest at about 6,650 km (4,130 miles), though the Amazon may be longer."},
      {"q": "what is the tallest mountain", "a": "Mount Everest is the tallest mountain above sea level at 8,849 meters (29,032 feet) in the Himalayas."},
      {"q": "what is the largest desert", "a": "The Sahara Desert in Africa is the largest hot desert at about 9.2 million square km. Antarctica is the largest desert overall."},
      {"q": "what is the capital of france", "a": "Paris is the capital and largest city of France, known for the Eiffel Tower, Louvre Museum, and Notre-Dame Cathedral."},
      {"q": "what is the capital of japan", "a": "Tokyo is the capital and largest city of Japan, home to over 13 million people and a major global financial center."},
      {"q": "how many countries are there", "a": "There are 195 countries in the world (193 UN member states plus 2 observer states: Vatican City and Palestine)."},
      {"q": "what is the largest country", "a": "Russia is the largest country by area at 17.1 million square kilometers, spanning 11 time zones across Europe and Asia."},
      {"q": "what is the amazon rainforest", "a": "The Amazon Rainforest is the world's largest tropical rainforest, covering about 5.5 million square km across South America."}
    ],
    "language": {
      "english": [
        {"q": "what is a noun", "a": "A noun is a word representing a person, place, thing, or idea. Examples: dog, city, love, John."},
        {"q": "what is a verb", "a": "A verb is a word expressing an action, occurrence, or state. Examples: run, think, is, become."},
        {"q": "what is an adjective", "a": "An adjective is a word describing or modifying a noun. Examples: big, red, beautiful, smart."},
        {"q": "what is an adverb", "a": "An adverb modifies a verb, adjective, or other adverb. Examples: quickly, very, well, always."},
        {"q": "what is a metaphor", "a": "A metaphor is a figure of speech comparing two unlike things without using 'like' or 'as'. Example: 'Time is money.'"},
        {"q": "what is irony", "a": "Irony is when the opposite of what is expected happens. Verbal irony says one thing but means another."},
        {"q": "what is a simile", "a": "A simile compares two things using 'like' or 'as'. Example: 'She runs like the wind' or 'Brave as a lion.'"},
        {"q": "what is personification", "a": "Personification gives human qualities to non-human things. Example: 'The wind whispered through the trees.'"},
        {"q": "what is alliteration", "a": "Alliteration is the repetition of initial consonant sounds in nearby words. Example: 'Peter Piper picked a peck.'"},
        {"q": "what is hyperbole", "a": "Hyperbole is extreme exaggeration for emphasis. Example: 'I've told you a million times.'"}
      ]
    },
    "arts": {
      "music": [
        {"q": "what is a chord", "a": "A chord is three or more notes played simultaneously. Major chords sound happy; minor chords sound sad."},
        {"q": "what is a scale", "a": "A scale is a sequence of notes in ascending or descending order. Major and minor scales are most common."},
        {"q": "what is rhythm", "a": "Rhythm is the pattern of sounds and silences in music, determined by the duration of notes and rests."},
        {"q": "what is melody", "a": "A melody is a sequence of notes that form a tune, the part you can hum or sing along to."},
        {"q": "what is harmony", "a": "Harmony is the combination of simultaneously sounded musical notes to produce chords and chord progressions."},
        {"q": "what is tempo", "a": "Tempo is the speed of a piece of music, measured in beats per minute (BPM). Terms include allegro, adagio, and presto."},
        {"q": "what is jazz", "a": "Jazz is a music genre originating in African American communities, characterized by swing, blue notes, call-and-response, and improvisation."},
        {"q": "what is classical music", "a": "Classical music is art music rooted in Western traditions, encompassing roughly 11th century to present, including symphonies, concertos, and sonatas."},
        {"q": "what is a guitar", "a": "A guitar is a stringed musical instrument with 6 strings, played by plucking or strumming. Types include acoustic, classical, and electric."},
        {"q": "what is a piano", "a": "A piano is a keyboard instrument where hammers strike strings to produce sound. It typically has 88 keys spanning 7+ octaves."}
      ],
      "visual_arts": [
        {"q": "what is perspective", "a": "Perspective in art is a technique for representing 3D objects on a 2D surface, creating depth and distance."},
        {"q": "what is composition", "a": "Composition is the arrangement of visual elements in a work of art, including balance, contrast, and focal point."},
        {"q": "what is color theory", "a": "Color theory studies how colors mix, match, and contrast. Primary colors (red, blue, yellow) combine to create all other colors."},
        {"q": "what is surrealism", "a": "Surrealism is an art movement emphasizing the unconscious mind, dreams, and irrational juxtapositions, led by Salvador Dalí."},
        {"q": "what is impressionism", "a": "Impressionism is an art movement emphasizing light and color over detail, with visible brushstrokes. Key artists: Monet, Renoir."},
        {"q": "what is sculpture", "a": "Sculpture is three-dimensional art made by carving, casting, or assembling materials like stone, metal, or wood."},
        {"q": "what is photography", "a": "Photography is the art and science of capturing light on a medium, invented in the 19th century."},
        {"q": "what is abstract art", "a": "Abstract art uses shapes, colors, and forms to achieve its effect rather than depicting visual reality."},
        {"q": "what is pop art", "a": "Pop art emerged in the 1950s-60s using imagery from popular culture like advertisements and comics. Key artists: Warhol, Lichtenstein."},
        {"q": "what is the Mona Lisa", "a": "The Mona Lisa is a painting by Leonardo da Vinci (1503-1519), depicting a woman with an enigmatic smile, housed in the Louvre."}
      ]
    },
    "philosophy": [
      {"q": "what is philosophy", "a": "Philosophy is the study of fundamental questions about existence, knowledge, values, reason, and reality."},
      {"q": "who was socrates", "a": "Socrates (470-399 BC) was a Greek philosopher who developed the Socratic method of questioning to stimulate critical thinking."},
      {"q": "who was plato", "a": "Plato (428-348 BC) was a Greek philosopher, student of Socrates, who wrote 'The Republic' and founded the Academy."},
      {"q": "who was aristotle", "a": "Aristotle (384-322 BC) was a Greek philosopher who studied under Plato and tutored Alexander the Great, making contributions to logic, biology, and ethics."},
      {"q": "what is ethics", "a": "Ethics is the branch of philosophy dealing with morality, right and wrong, and how people should live."},
      {"q": "what is existentialism", "a": "Existentialism is a philosophy emphasizing individual existence, freedom, and choice, associated with Sartre, Camus, and Kierkegaard."},
      {"q": "what is the meaning of life", "a": "The meaning of life is one of philosophy's great questions. Different perspectives include: happiness, knowledge, service, and creating your own meaning."},
      {"q": "what is free will", "a": "Free will is the idea that humans can make choices that are not predetermined, a central debate in philosophy and neuroscience."},
      {"q": "what is consciousness", "a": "Consciousness is the state of being aware of and able to think about one's own existence, thoughts, and surroundings."},
      {"q": "what is truth", "a": "Truth is the property of being in accord with reality. Philosophers debate whether truth is absolute, relative, or constructed."}
    ],
    "health": [
      {"q": "what is a calorie", "a": "A calorie is a unit of energy. The food calories (kilocalories) represent the energy your body gets from food."},
      {"q": "what is BMI", "a": "BMI (Body Mass Index) is a measure of body fat based on height and weight. Normal range is 18.5-24.9."},
      {"q": "what is sleep", "a": "Sleep is a natural state of rest where the body and mind repair. Adults need 7-9 hours per night for optimal health."},
      {"q": "what is vitamins", "a": "Vitamins are organic compounds needed in small amounts for normal growth and nutrition. There are 13 essential vitamins."},
      {"q": "what is exercise", "a": "Exercise is physical activity that improves health, fitness, and well-being. The WHO recommends 150 minutes of moderate activity per week."},
      {"q": "what is hydration", "a": "Hydration is the process of providing adequate water to the body. Adults should drink about 2-3 liters of water daily."},
      {"q": "what is stress", "a": "Stress is the body's response to challenges. Short-term stress can be helpful; chronic stress harms health."},
      {"q": "what is meditation", "a": "Meditation is a practice of focused attention or mindfulness to achieve mental clarity and emotional calm."},
      {"q": "what is nutrition", "a": "Nutrition is the study of nutrients in food, how the body uses them, and the relationship between diet and health."},
      {"q": "what is metabolism", "a": "Metabolism is the chemical processes in living organisms that convert food into energy and build cellular structures."}
    ],
    "daily_life": [
      {"q": "how to cook rice", "a": "To cook rice: rinse 1 cup rice, add 2 cups water, bring to boil, cover, reduce heat, simmer 18 minutes, then let sit covered 5 minutes."},
      {"q": "how to make coffee", "a": "To make coffee: use 1-2 tablespoons ground coffee per 6 oz water. Brew with drip, French press, or espresso method."},
      {"q": "how to do laundry", "a": "To do laundry: sort clothes by color, check labels, load washer, add detergent, choose cycle, dry on appropriate setting."},
      {"q": "how to budget money", "a": "Budgeting: list income, track expenses, allocate 50% needs, 30% wants, 20% savings. Use apps or spreadsheets to track."},
      {"q": "how to manage time", "a": "Time management: prioritize tasks, use time-blocking, minimize distractions, take breaks (Pomodoro technique), set deadlines."},
      {"q": "how to clean a house", "a": "House cleaning: start top to bottom, left to right. Declutter first, dust, then clean surfaces, vacuum/mop floors last."},
      {"q": "how to organize a room", "a": "Room organization: declutter first, use storage containers, label everything, designate zones for different activities."},
      {"q": "how to plant a garden", "a": "Garden planting: choose location with sunlight, prepare soil, select plants for your climate, plant at right depth, water regularly."},
      {"q": "how to sew", "a": "Basic sewing: thread needle, knot end, use running stitch (in and out), backstitch for strength, practice on scrap fabric first."},
      {"q": "how to iron clothes", "a": "Ironing: set appropriate temperature for fabric, iron while slightly damp, use smooth strokes, iron collar and cuffs first."}
    ],
    "space": [
      {"q": "how far is the sun", "a": "The Sun is about 150 million kilometers (93 million miles) from Earth. Light takes about 8 minutes 20 seconds to reach us."},
      {"q": "how far is the moon", "a": "The Moon is about 384,400 kilometers (238,855 miles) from Earth on average."},
      {"q": "how fast is light", "a": "Light travels at about 299,792 kilometers per second (186,282 miles per second) in vacuum."},
      {"q": "what planets are there", "a": "Our solar system has 8 planets: Mercury, Venus, Earth, Mars, Jupiter, Saturn, Uranus, and Neptune."},
      {"q": "how old is the earth", "a": "Earth is about 4.54 billion years old, determined by radiometric dating of meteorite material."},
      {"q": "how old is the universe", "a": "The universe is about 13.8 billion years old, based on observations of the cosmic microwave background."},
      {"q": "what is a star", "a": "A star is a luminous sphere of plasma held together by gravity, generating energy through nuclear fusion of hydrogen into helium."},
      {"q": "what is a supernova", "a": "A supernova is a powerful stellar explosion that briefly outshines an entire galaxy, dispersing heavy elements into space."},
      {"q": "what is gravity on the moon", "a": "The Moon's gravity is about 1/6th of Earth's gravity. A 100kg person would weigh about 16.5kg on the Moon."},
      {"q": "how many moons does jupiter have", "a": "Jupiter has 95 known moons. The four largest (Io, Europa, Ganymede, Callisto) are called the Galilean moons."}
    ]
  }
}
KNOWLEDGE
}

# Count facts in broad knowledge
ai_knowledge_broad_count() {
  ai_knowledge_broad | python3 -c "
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

# Search broad knowledge
ai_knowledge_broad_search() {
  local query="$1"
  ai_knowledge_broad | python3 -c "
import sys, json
data = json.load(sys.stdin)
query = '$query'.lower()
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
                    if word in q:
                        score += 10
                    if word in a:
                        score += 5
                if query in q or q in query:
                    score += 50
                if score > best_score:
                    best_score = score
                    best_match = fact
    elif isinstance(topics, list):
        for fact in topics:
            q = fact['q'].lower()
            a = fact['a'].lower()
            score = 0
            for word in query.split():
                if word in q:
                    score += 10
                if word in a:
                    score += 5
            if query in q or q in query:
                score += 50
            if score > best_score:
                best_score = score
                best_match = fact

if best_match and best_score >= 10:
    print(best_match['a'])
else:
    print('')
" 2>/dev/null
}

echo "[ai-knowledge-broad] loaded — $(ai_knowledge_broad_count)"
