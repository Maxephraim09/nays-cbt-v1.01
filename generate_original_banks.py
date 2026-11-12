import json
from pathlib import Path

OUT = Path("assets/database/question_bank/questions")
SOURCE = "Original practice; generated content requires qualified editorial review"
STATUS = "editorial_review_required"


def build_vocabulary(subject, cards):
    rows = []
    for group, topic, entries in cards:
        for i, (term, meaning) in enumerate(entries):
            alternatives = [entry for entry in entries if entry != (term, meaning)]
            wrong_meanings = [value[1] for value in alternatives[:3]]
            wrong_terms = [value[0] for value in alternatives[:3]]
            rows.append({
                "topic": group,
                "subtopic": topic,
                "answer": meaning,
                "meaning": meaning,
                "wrong": wrong_meanings,
                "q1": f"What is the closest standard English meaning of “{term}”?",
                "q2": f"Which {subject.title()} word means “{meaning}”?",
                "answer2": term,
                "wrong2": wrong_terms,
                "explanation": f"In standard {subject.title()}, “{term}” means “{meaning}”; the other choices belong to different meanings in this topic.",
            })
    return rows


def grammar_card(topic, subtopic, q1, q2, answer, wrong, explanation):
    return {
        "topic": topic, "subtopic": subtopic, "q1": q1, "q2": q2,
        "answer": answer, "wrong": wrong, "answer2": answer, "wrong2": wrong,
        "explanation": explanation,
    }


def art_card(topic, subtopic, q1, q2, answer, wrong, explanation):
    return grammar_card(topic, subtopic, q1, q2, answer, wrong, explanation)


ARABIC_VOCAB = [
    ("Vocabulary", "School objects", [
        ("كتاب", "book"), ("قلم", "pen"), ("دفتر", "notebook"),
        ("كرسي", "chair"), ("نافذة", "window"),
    ]),
    ("Vocabulary", "Home and places", [
        ("بيت", "house"), ("باب", "door"), ("غرفة", "room"),
        ("مطبخ", "kitchen"), ("مدرسة", "school"),
    ]),
    ("Vocabulary", "People and family", [
        ("أم", "mother"), ("أب", "father"), ("أخ", "brother"),
        ("أخت", "sister"), ("معلم", "male teacher"),
    ]),
    ("Vocabulary", "Nature and time", [
        ("شمس", "sun"), ("قمر", "moon"), ("ماء", "water"),
        ("ليل", "night"), ("يوم", "day"),
    ]),
    ("Vocabulary", "Common verbs", [
        ("يقرأ", "he reads"), ("يكتب", "he writes"), ("يفتح", "he opens"),
        ("يغلق", "he closes"), ("يدرس", "he studies"),
    ]),
]

FRENCH_VOCAB = [
    ("Vocabulary", "School objects", [
        ("un livre", "a book"), ("un stylo", "a pen"), ("un cahier", "a notebook"),
        ("une chaise", "a chair"), ("une fenêtre", "a window"),
    ]),
    ("Vocabulary", "Home and places", [
        ("une maison", "a house"), ("une porte", "a door"), ("une chambre", "a bedroom"),
        ("une cuisine", "a kitchen"), ("une école", "a school"),
    ]),
    ("Vocabulary", "People and family", [
        ("une mère", "a mother"), ("un père", "a father"), ("un frère", "a brother"),
        ("une sœur", "a sister"), ("un ami", "a male friend"),
    ]),
    ("Vocabulary", "Nature and time", [
        ("le soleil", "the sun"), ("la lune", "the moon"), ("l’eau", "water"),
        ("la nuit", "the night"), ("un jour", "a day"),
    ]),
    ("Vocabulary", "Common verbs", [
        ("lire", "to read"), ("écrire", "to write"), ("ouvrir", "to open"),
        ("fermer", "to close"), ("étudier", "to study"),
    ]),
]

IGBO_VOCAB = [
    ("Vocabulary", "School and places", [
        ("ụlọ akwụkwọ", "school"), ("akwụkwọ", "book"), ("onye nkuzi", "teacher"),
        ("ụlọ", "house"), ("ahịa", "market"),
    ]),
    ("Vocabulary", "Family and people", [
        ("nne", "mother"), ("nna", "father"), ("nwa", "child"),
        ("nwanne", "sibling"), ("enyi", "friend"),
    ]),
    ("Vocabulary", "Food", [
        ("ji", "yam"), ("osikapa", "rice"), ("anụ", "meat"),
        ("azụ", "fish"), ("nnu", "salt"),
    ]),
    ("Vocabulary", "Nature", [
        ("mmiri", "water"), ("anyanwụ", "sun"), ("ikuku", "air"),
        ("ọkụ", "fire"), ("osisi", "tree"),
    ]),
    ("Vocabulary", "Time and daily life", [
        ("oge", "time"), ("ụbọchị", "day"), ("taa", "today"),
        ("echi", "tomorrow"), ("abalị", "night"),
    ]),
]

ARABIC_GRAMMAR = [
    grammar_card("Grammar", "Definite article", "Which Arabic prefix makes a common noun definite?", "A speaker changes كتاب to الكتاب to mean “the book.” Which grammatical marker was added?", "الـ", ["في", "من", "إلى"], "The attached definite article الـ changes كتاب (a book) to الكتاب (the book)."),
    grammar_card("Grammar", "Demonstratives", "Which demonstrative is used with a nearby masculine singular noun?", "To point to a nearby book (كتاب), which form of “this” is appropriate?", "هذا", ["هذه", "هؤلاء", "ذلك"], "هذا is the masculine singular demonstrative for a nearby referent; هذه is feminine and ذلك is distant."),
    grammar_card("Grammar", "Demonstratives", "Which demonstrative normally agrees with a nearby feminine singular noun?", "A learner points to a nearby مدرسة (school). Which word for “this” fits its grammatical gender?", "هذه", ["هذا", "هؤلاء", "ذلك"], "هذه is the nearby feminine singular demonstrative, agreeing with مدرسة."),
    grammar_card("Grammar", "Pronouns", "Which Arabic pronoun means “I”?", "A learner speaking only about themself begins with which Arabic pronoun?", "أنا", ["نحن", "هو", "هم"], "أنا means “I”; نحن is “we,” هو is “he,” and هم is “they.”"),
    grammar_card("Grammar", "Pronouns", "Which pronoun means “we”?", "A group including the speaker introduces itself. Which Arabic pronoun means “we”?", "نحن", ["أنا", "هي", "أنت"], "نحن means “we,” including the speaker and at least one other person."),
    grammar_card("Grammar", "Pronouns", "Which Arabic pronoun means “she”?", "For a single female person as the subject, which pronoun is used?", "هي", ["هو", "هم", "أنا"], "هي is the third-person feminine singular pronoun, “she.”"),
    grammar_card("Grammar", "Pronouns", "Which Arabic pronoun means “they” for a masculine or mixed group?", "When referring to a group of men or a mixed group, which pronoun means “they”?", "هم", ["هن", "هو", "نحن"], "هم is the masculine or mixed plural “they”; هن is the feminine plural."),
    grammar_card("Grammar", "Prepositions", "Which preposition means “in” or “inside”?", "To express “in the house” (___ البيت), which preposition is needed?", "في", ["على", "إلى", "من"], "في means “in”; في البيت means “in the house.”"),
    grammar_card("Grammar", "Prepositions", "Which preposition means “on” or “upon”?", "To express a book resting on a table (الكتاب ___ الطاولة), which preposition fits?", "على", ["في", "من", "إلى"], "على means “on/upon,” as in على الطاولة (on the table)."),
    grammar_card("Grammar", "Prepositions", "Which preposition commonly means “to” when indicating direction?", "In a phrase meaning “to the school,” which preposition supplies “to”?", "إلى", ["من", "في", "عن"], "إلى indicates direction toward a destination and commonly translates as “to.”"),
    grammar_card("Grammar", "Nominal sentences", "What is the usual name for the subject of an Arabic nominal sentence?", "In a sentence beginning with a noun, what is the initial subject called in Arabic grammar?", "مبتدأ", ["خبر", "فعل", "مفعول به"], "The مبتدأ is the topic or subject of a nominal sentence; its خبر supplies information about it."),
    grammar_card("Grammar", "Nominal sentences", "What is the predicate of a basic Arabic nominal sentence called?", "In a nominal sentence, which term names the part that completes the statement about the مبتدأ?", "خبر", ["مبتدأ", "فاعل", "حرف جر"], "The خبر is the predicate that gives information about the مبتدأ."),
    grammar_card("Grammar", "Verb sentences", "What commonly begins a basic Arabic verbal sentence?", "A sentence arranged as a verbal sentence typically places which element first?", "A verb", ["A preposition", "A conjunction", "A possessive suffix"], "A basic verbal sentence (جملة فعلية) begins with a verb, commonly followed by its subject."),
    grammar_card("Grammar", "Verb forms", "Which tense is commonly expressed by كتب in a basic context?", "In a simple narrative, كتب الرجل means that the man did what?", "He wrote", ["He writes", "He will write", "He is writing now"], "كتب is the third-person masculine singular perfect form, commonly translated “he wrote.”"),
    grammar_card("Grammar", "Verb forms", "Which tense is commonly expressed by يكتب in a basic context?", "In a simple present-tense statement, يكتب الطالب means that the student does what?", "He writes", ["He wrote", "He had written", "Write!"], "يكتب is an imperfect verb form used for present or habitual action in a basic context."),
    grammar_card("Grammar", "Gender agreement", "Which adjective ending commonly marks feminine singular agreement?", "A feminine singular noun such as طالبة is described with a regular adjective. Which ending is commonly used?", "ـة", ["ـون", "ـان", "ـين"], "The tāʾ marbūṭa (ـة) commonly marks feminine singular forms, including adjectives agreeing with feminine nouns."),
    grammar_card("Grammar", "Dual", "Which ending commonly marks the nominative dual of a regular Arabic noun?", "A learner refers to two students in a nominative context. Which common dual ending is expected?", "ـان", ["ـون", "ـات", "ـة"], "Regular sound dual nouns commonly take ـان in the nominative and ـين in the accusative or genitive."),
    grammar_card("Grammar", "Sound masculine plural", "Which ending commonly marks the nominative sound masculine plural?", "For a regular sound masculine plural in a nominative context, which ending is used?", "ـون", ["ـات", "ـان", "ـة"], "The sound masculine plural commonly ends in ـون in the nominative and ـين in oblique cases."),
    grammar_card("Grammar", "Sound feminine plural", "Which suffix commonly forms a sound feminine plural?", "A regular feminine noun is pluralized without changing its stem. Which suffix commonly marks that plural?", "ـات", ["ـون", "ـان", "ـة"], "The sound feminine plural commonly uses the suffix ـات."),
    grammar_card("Grammar", "Sun letters", "What happens to the ل sound of ال before a sun letter in pronunciation?", "In الشمس (the sun), why is the lām of ال not heard as a separate sound?", "It assimilates to the following sun letter", ["It becomes a long vowel", "It is pronounced as a hamza", "It moves to the end of the word"], "Before a sun letter, the lām of ال assimilates in pronunciation; the following consonant is doubled."),
    grammar_card("Grammar", "Moon letters", "How is the ل of ال pronounced before a moon letter?", "In القمر (the moon), what happens to the lām of the definite article in pronunciation?", "It is pronounced clearly", ["It assimilates to ق", "It is omitted from spelling", "It becomes a tanwīn"], "ق is a moon letter, so the lām in ال is pronounced clearly in القمر."),
    grammar_card("Grammar", "Interrogatives", "Which Arabic question word means “who”?", "To ask about a person's identity, which Arabic interrogative means “who”?", "من", ["ماذا", "أين", "متى"], "من means “who”; ماذا asks “what,” أين asks “where,” and متى asks “when.”"),
    grammar_card("Grammar", "Interrogatives", "Which Arabic question word means “where”?", "A speaker asks for the location of a school. Which interrogative means “where”?", "أين", ["من", "متى", "كيف"], "أين asks “where,” a question about place or location."),
    grammar_card("Grammar", "Interrogatives", "Which Arabic question word means “when”?", "To ask about the time of an event, which interrogative is used?", "متى", ["أين", "من", "لماذا"], "متى means “when,” asking about time."),
    grammar_card("Grammar", "Adjective agreement", "In a basic Arabic noun phrase, what generally happens to a descriptive adjective's definiteness?", "If a noun is definite and followed by a directly attributive adjective, how does the adjective normally agree in definiteness?", "It is definite as well", ["It must be indefinite", "It becomes a verb", "It takes a preposition"], "A directly attributive adjective generally agrees with its noun in definiteness as well as gender, number and case."),
]

FRENCH_GRAMMAR = [
    grammar_card("Grammar", "Articles", "Which definite article is used with a masculine singular noun such as livre?", "A speaker says “___ livre” to mean “the book.” Which article completes the phrase?", "le", ["la", "les", "une"], "Le is the definite article for a masculine singular noun; livre is masculine."),
    grammar_card("Grammar", "Articles", "Which definite article is used with a feminine singular noun such as maison?", "To say “the house” in French, which article precedes maison?", "la", ["le", "les", "un"], "La is the feminine singular definite article, as in la maison."),
    grammar_card("Grammar", "Articles", "Which definite article is used with plural nouns of either grammatical gender?", "A student wants to say “the books.” Which French definite article precedes plural livres?", "les", ["le", "la", "une"], "Les is the definite plural article for masculine and feminine plural nouns."),
    grammar_card("Grammar", "Articles", "Which indefinite article normally precedes a masculine singular noun?", "To say “a pen” before the masculine noun stylo, which article is appropriate?", "un", ["une", "des", "la"], "Un is the indefinite article for a masculine singular noun; stylo is masculine."),
    grammar_card("Grammar", "Articles", "Which indefinite article normally precedes a feminine singular noun?", "To say “a chair” before the feminine noun chaise, which article is appropriate?", "une", ["un", "des", "le"], "Une is the indefinite article for a feminine singular noun, as in une chaise."),
    grammar_card("Grammar", "Pronouns", "Which French subject pronoun means “we”?", "A group including the speaker replaces its name as the subject. Which pronoun means “we”?", "nous", ["vous", "ils", "elle"], "Nous means “we”; vous means “you,” ils means “they” (masculine/mixed), and elle means “she.”"),
    grammar_card("Grammar", "Pronouns", "Which French subject pronoun means “they” for an all-feminine group?", "When a subject is a group of women, which subject pronoun means “they”?", "elles", ["ils", "elles-mêmes", "elle"], "Elles is the feminine plural subject pronoun; ils is used for masculine or mixed groups."),
    grammar_card("Grammar", "Pronouns", "Which subject pronoun means formal or plural “you”?", "A student addresses a teacher politely or speaks to several people. Which pronoun is suitable?", "vous", ["tu", "nous", "on"], "Vous is used for plural “you” and also for formal singular address."),
    grammar_card("Grammar", "Present tense", "What is the usual present form of être with je?", "Complete the sentence: Je ___ élève. (I am a pupil.)", "suis", ["es", "est", "sommes"], "Je suis is the first-person singular present form of être."),
    grammar_card("Grammar", "Present tense", "What is the usual present form of avoir with nous?", "Complete: Nous ___ un livre. (We have a book.)", "avons", ["avez", "ont", "as"], "Nous avons is the first-person plural present form of avoir."),
    grammar_card("Grammar", "Present tense", "What is the present form of aller with vous?", "Complete: Vous ___ à l’école. (You are going to school.)", "allez", ["allons", "vas", "vont"], "Vous allez is the second-person plural/formal present form of aller."),
    grammar_card("Grammar", "Present tense", "Which present ending commonly completes a regular -er verb with je?", "For a regular -er verb such as parler, which ending forms je parle?", "-e", ["-ons", "-ez", "-ent"], "Regular -er verbs take -e in the first-person singular present: je parle."),
    grammar_card("Grammar", "Present tense", "Which ending commonly completes a regular -er verb with nous?", "For a regular -er verb such as parler, which ending forms nous parlons?", "-ons", ["-e", "-ez", "-ent"], "Regular -er verbs take -ons with nous in the present tense."),
    grammar_card("Grammar", "Negation", "Where is ne normally placed in a simple French negation with a conjugated verb?", "In ne parle pas, where does ne appear relative to the conjugated verb?", "Before the conjugated verb", ["After the verb", "After pas", "At the end of the sentence only"], "In the standard ne…pas pattern, ne precedes and pas follows the conjugated verb."),
    grammar_card("Grammar", "Negation", "Which word normally follows the verb in the ne…pas pattern?", "To make parle negative, the frame is ne parle ___. Which word completes it?", "pas", ["plus", "jamais", "rien"], "Pas is the common second part of ne…pas, the basic French negation."),
    grammar_card("Grammar", "Adjective agreement", "What normally happens to a French adjective describing a feminine singular noun?", "If petit describes the feminine singular noun maison, what agreement change is normally made?", "Add -e", ["Add -s only", "Change it to an infinitive", "Remove the final consonant in every case"], "Many French adjectives add -e for feminine singular agreement: petit becomes petite."),
    grammar_card("Grammar", "Adjective agreement", "What marker commonly indicates a regular adjective agrees with a plural noun in writing?", "A regular adjective describes several masculine nouns. Which written marker is commonly added?", "Add -s", ["Add -e only", "Add -ons", "Replace it with -ent"], "Many regular French adjectives add a written -s in the plural, usually not pronounced."),
    grammar_card("Grammar", "Questions", "Which inversion is a standard way to form a question with il parle?", "To ask “Does he speak?” using inversion, which form is correct?", "Parle-t-il ?", ["Il parle-t ?", "Parles-il ?", "Parle il-t ?"], "In subject–verb inversion, parle and il are joined with -t- for pronunciation: Parle-t-il ?"),
    grammar_card("Grammar", "Questions", "Which French question word means “where”?", "To ask where someone lives, which question word means “where”?", "où", ["qui", "quand", "pourquoi"], "Où means “where”; qui means “who,” quand means “when,” and pourquoi means “why.”"),
    grammar_card("Grammar", "Questions", "Which French question word means “when”?", "To ask at what time an event occurs, which question word is used?", "quand", ["où", "qui", "comment"], "Quand means “when” and asks about time."),
    grammar_card("Grammar", "Prepositions", "Which contracted form combines à and le?", "Before a masculine singular noun, à + le becomes which form?", "au", ["à la", "aux", "du"], "À + le contracts to au; à la and aux do not result from this masculine singular combination."),
    grammar_card("Grammar", "Prepositions", "Which contracted form combines de and les?", "In a phrase meaning “of the books,” de + les contracts to which form?", "des", ["du", "de la", "aux"], "De + les contracts to des."),
    grammar_card("Grammar", "Possessives", "Which possessive adjective means “my” before a masculine singular noun?", "To say “my book” before masculine singular livre, which possessive adjective is used?", "mon", ["ma", "mes", "ton"], "Mon is the masculine singular possessive adjective for “my,” as in mon livre."),
    grammar_card("Grammar", "Possessives", "Which possessive adjective means “my” before a feminine singular noun beginning with a consonant?", "To say “my house” before feminine singular maison, which possessive adjective is used?", "ma", ["mon", "mes", "son"], "Ma is the feminine singular possessive adjective for “my” before a consonant: ma maison."),
    grammar_card("Grammar", "Pronunciation and spelling", "What happens to the final consonant in many French words when it is followed by a vowel-starting word in liaison?", "In les amis, how is the normally silent final s commonly realized in connected speech?", "It is pronounced as a linking /z/", ["It is deleted from spelling", "It becomes /k/", "It is pronounced as /ʃ/"], "In the liaison les amis, the final s is linked to the following vowel and pronounced /z/."),
]

IGBO_GRAMMAR = [
    grammar_card("Grammar", "Pronouns", "Which standard Igbo pronoun means “we”?", "A group including the speaker refers to itself. Which Igbo pronoun means “we”?", "anyị", ["m", "ị", "ọ"], "anyị is the first-person plural pronoun, “we.”"),
    grammar_card("Grammar", "Pronouns", "Which standard Igbo pronoun means “I” or “me”?", "A speaker refers to themself with a subject pronoun. Which form means “I”?", "m", ["anyị", "ha", "ị"], "m is the first-person singular pronoun; its precise role can depend on sentence position."),
    grammar_card("Grammar", "Pronouns", "Which Igbo pronoun can mean “he,” “she,” or “it”?", "A single third-person subject is mentioned without marking gender. Which Igbo pronoun is used?", "ọ", ["ha", "anyị", "unu"], "ọ is a third-person singular pronoun and does not distinguish gender in the way English does."),
    grammar_card("Grammar", "Pronouns", "Which Igbo pronoun means “they”?", "When referring to several people as the subject, which standard Igbo pronoun means “they”?", "ha", ["ọ", "ị", "m"], "ha is the third-person plural pronoun, “they.”"),
    grammar_card("Grammar", "Question words", "Which Igbo question word means “who”?", "To ask about a person's identity, which Igbo word means “who”?", "onye", ["gịnị", "ebe", "ole"], "onye means “who/person”; gịnị means “what,” ebe means “where/place,” and ole asks “how many/how much.”"),
    grammar_card("Grammar", "Question words", "Which Igbo question word means “what”?", "A speaker asks for the name of an object. Which question word means “what”?", "gịnị", ["onye", "ebe", "oge"], "gịnị is the standard question word for “what.”"),
    grammar_card("Grammar", "Question words", "Which Igbo question word means “where”?", "To ask for a location, which Igbo question word is used?", "ebee", ["gịnị", "onye", "ole"], "Ebee means “where” and is used in location questions."),
    grammar_card("Grammar", "Question words", "Which Igbo word asks “how many” or “how much”?", "A learner asks for a quantity. Which question word is appropriate?", "ole", ["onye", "gịnị", "ebe"], "ole asks about quantity, corresponding to “how many” or “how much.”"),
    grammar_card("Grammar", "Orthography", "Which character is the dotted-under vowel in standard Igbo orthography?", "Which letter completes the standard vowel set in the word anyị?", "ị", ["i", "e", "u"], "ị is a distinct dotted-under vowel in standard Igbo orthography; it is not interchangeable with i."),
    grammar_card("Grammar", "Orthography", "Which character is the dotted-under open-o vowel?", "In standard Igbo spelling, which distinct letter appears in ọkụ (fire)?", "ọ", ["o", "a", "ụ"], "ọ is the dotted-under open-o vowel; standard orthography distinguishes it from o."),
    grammar_card("Grammar", "Orthography", "Which character is the dotted-under u vowel?", "Which distinct vowel is used in ụtụtụ (morning)?", "ụ", ["u", "ọ", "ị"], "ụ is the dotted-under u vowel in standard Igbo spelling."),
    grammar_card("Grammar", "Orthography", "Which spelling represents the syllabic nasal in standard Igbo writing?", "In a word such as ṅụọ, which marked letter identifies the syllabic nasal?", "ṅ", ["n", "ñ", "ŋ"], "Standard Igbo uses ṅ for the syllabic nasal; the dot distinguishes it from n."),
    grammar_card("Grammar", "Orthography", "Why must the letters ị, ọ, and ụ be preserved when writing Igbo?", "A student removes all underdots from an Igbo sentence. What important distinction may be lost?", "Distinct vowel identity and meaning", ["Word order", "Plural punctuation", "Sentence capitalization"], "The underdot vowels are separate letters in standard Igbo orthography and can distinguish words."),
    grammar_card("Grammar", "Noun phrases", "In akwụkwọ m, what does the final m express?", "A learner writes akwụkwọ m for “my book.” What meaning does m add?", "My (possession by the speaker)", ["Plurality", "Past tense", "A question"], "Placed after the noun, m expresses first-person possession in akwụkwọ m (“my book”)."),
    grammar_card("Grammar", "Noun phrases", "How is the quantity “two books” expressed using akwụkwọ and abụọ?", "Choose the phrase that means “two books” without adding an English-style plural suffix.", "akwụkwọ abụọ", ["abụọ akwụkwọ", "akwụkwọ abụọ ndị", "akwụkwọ -s abụọ"], "akwụkwọ abụọ means “two books”; Igbo expresses the number with abụọ rather than an English -s ending."),
    grammar_card("Grammar", "Numbers", "Which Igbo numeral means “one”?", "A learner counts one object. Which standard Igbo word means “one”?", "otu", ["abụọ", "atọ", "anọ"], "otu means “one”; abụọ, atọ, and anọ mean two, three, and four."),
    grammar_card("Grammar", "Numbers", "Which Igbo numeral means “two”?", "Which number word completes ụmụ akwụkwọ ___ for “two pupils/students”?", "abụọ", ["otu", "atọ", "ise"], "abụọ means “two” and follows the noun in a phrase such as ụmụ akwụkwọ abụọ (two pupils)."),
    grammar_card("Grammar", "Numbers", "Which Igbo numeral means “three”?", "A count of three objects is expressed with which Igbo numeral?", "atọ", ["abụọ", "anọ", "ise"], "atọ means “three”; for example, akwụkwọ atọ means “three books.”"),
    grammar_card("Grammar", "Negation", "Which element commonly marks negation in the Igbo phrase anaghị m?", "In anaghị m aga (I do not go), what meaning does anaghị contribute?", "A negative present/habitual meaning", ["A future marker", "A plural noun marker", "A question word"], "anaghị m is a common way to express “I do not” in a present or habitual context."),
    grammar_card("Grammar", "Tense and aspect", "In a basic future expression, what does ga commonly contribute before a verb?", "In the pattern Aga m aga (I will go), what does the first ga signal?", "Future meaning", ["Past completion", "Plural agreement", "A location"], "In this future construction, ga marks prospective/future meaning; Aga m aga means “I will go.”"),
    grammar_card("Grammar", "Word order", "In a basic affirmative Igbo clause, where does the subject generally occur relative to the verb?", "In a simple clause such as Nwa ahụ na-agụ akwụkwọ, which element comes before the verb phrase?", "The subject", ["The object only", "A postposed subject marker", "The question word"], "A basic affirmative clause places its subject before the verb phrase, as Nwa ahụ na-agụ… illustrates."),
    grammar_card("Grammar", "Aspect", "In a common Igbo construction, what does na- before a verb often indicate?", "In na-agụ (is reading/reads), what aspectual sense does na- commonly help express?", "Ongoing or habitual action", ["A noun plural", "A completed past action only", "A possessive"], "The prefix na- commonly marks ongoing or habitual action in contexts such as na-agụ."),
    grammar_card("Grammar", "Noun phrases", "In ụlọ ahụ, what does ahụ mean?", "A speaker identifies “that house” with ụlọ ahụ. What function does ahụ serve?", "A demonstrative meaning “that”", ["A plural suffix", "A verb meaning “build”", "A question marker"], "When it follows a noun, ahụ functions as the demonstrative “that,” as in ụlọ ahụ (that house)."),
    grammar_card("Grammar", "Punctuation", "Which punctuation mark normally ends a direct Igbo question in writing?", "A written direct question such as Gịnị ka ị chọrọ ends with which mark?", "A question mark (?)", ["A colon (:)", "A semicolon (;)", "A comma (, only)"], "A direct question is conventionally ended with a question mark in standard writing."),
    grammar_card("Grammar", "Tones", "Why are tone marks useful in Igbo learning materials?", "A learner sees two otherwise similar syllables marked with different tones. What can the marks indicate?", "A difference in pitch pattern that may distinguish meaning", ["A required plural ending", "A silent consonant deletion", "A French-style liaison"], "Igbo is tonal; tone marks can guide pitch and distinguish meanings, though everyday orthography may omit them."),
]

FINE_ARTS = [
    art_card("Elements of art", "Line", "Which element of art is a moving point that can outline a shape or guide the eye?", "A student draws a continuous mark to lead a viewer across a page. Which element is the mark?", "Line", ["Texture", "Value", "Form"], "A line is a mark with length and direction; it can define edges, suggest movement, or guide attention."),
    art_card("Elements of art", "Colour", "In the traditional artists’ RYB pigment model, which set contains the primary colours?", "A painter starts with the traditional pigment primaries. Which set should be used?", "Red, yellow and blue", ["Green, orange and violet", "Red, green and blue", "Yellow, orange and green"], "In the traditional RYB pigment model taught in basic art, red, yellow, and blue are primary colours."),
    art_card("Elements of art", "Colour", "Which secondary colour results from mixing blue and yellow pigments?", "A painter mixes blue and yellow paint in equal amounts. Which secondary colour is expected?", "Green", ["Violet", "Orange", "Brown"], "In the traditional pigment colour wheel, blue and yellow combine to produce green."),
    art_card("Elements of art", "Value", "Which element describes how light or dark a colour or tone appears?", "An artist varies a grey from almost white to nearly black. Which visual element is being changed?", "Value", ["Line", "Shape", "Texture"], "Value describes relative lightness and darkness, whether in a colour or a neutral tone."),
    art_card("Elements of art", "Texture", "Which element refers to the actual or perceived surface quality of an artwork?", "A viewer describes a painted surface as appearing rough even though it is smooth. Which element is described?", "Texture", ["Space", "Balance", "Proportion"], "Texture is the surface quality of a work; it may be tactile or only visually suggested."),
    art_card("Elements of art", "Shape", "Which element is a two-dimensional enclosed area?", "A flat triangular area enclosed by lines is an example of which element?", "Shape", ["Form", "Value", "Perspective"], "A shape is a two-dimensional enclosed area; form describes volume in three dimensions."),
    art_card("Elements of art", "Form", "Which element describes an object with three-dimensional volume?", "A clay sphere occupies height, width, and depth. Which element does it demonstrate?", "Form", ["Shape", "Line", "Pattern"], "Form describes three-dimensional volume, real or represented."),
    art_card("Elements of art", "Space", "What is positive space in a composition?", "In a poster, the illustrated figure occupies one area and the blank background another. What is the figure's area called?", "The area occupied by the subject or forms", ["Only the blank background", "The darkest value", "The outline thickness"], "Positive space is occupied by the subject or forms; negative space is the surrounding or intervening area."),
    art_card("Elements of art", "Colour", "Which group is commonly classified as warm colours?", "A designer wants a warm palette. Which group best fits that description?", "Red, orange and yellow", ["Blue, green and violet", "Blue, violet and green", "Black, white and grey"], "Reds, oranges, and yellows are conventionally described as warm colours."),
    art_card("Elements of art", "Colour", "What is a tint of a colour?", "A painter adds white to a hue to make a lighter version. What has been made?", "A tint", ["A shade", "A complement", "A neutral"], "A tint is made by adding white to a colour; adding black produces a shade."),
    art_card("Elements of art", "Colour", "What is a shade of a colour?", "A painter adds black to a hue to darken it. What is the result called?", "A shade", ["A tint", "A primary colour", "A highlight"], "A shade is made by adding black to a colour, reducing its lightness."),
    art_card("Techniques", "Collage", "Which technique creates an image by assembling and attaching separate materials to a surface?", "A student glues pieces of paper and fabric together to make one composition. Which technique is used?", "Collage", ["Modelling", "Etching", "Fresco"], "Collage builds a composition by attaching separate materials such as paper, fabric, or photographs."),
    art_card("Elements of art", "Line", "What is a contour line mainly used to describe?", "An outline drawing follows the visible edges of a cup. What kind of line is doing this work?", "A contour line", ["A vanishing line", "A hatch", "A radial line"], "Contour lines describe the visible edges and boundaries of a form."),
    art_card("Design", "Motif", "What is a motif in a decorative design?", "A designer repeats one small leaf shape throughout a cloth pattern. What is the repeated unit called?", "A motif", ["A vanishing point", "A ground", "A tint"], "A motif is a distinctive unit or image that may be repeated to form a pattern."),
    art_card("Techniques", "Watercolour", "What quality is characteristic of transparent watercolour washes?", "A painter wants underlying paper and earlier layers to remain visible through a thin wash. Which medium suits this method?", "Transparent watercolour", ["Opaque encaustic", "Oil pastel", "Wet clay"], "Transparent watercolour washes allow light from the paper and underlying layers to show through."),
    art_card("Colour", "Colour relationships", "On a conventional colour wheel, where are complementary colours located?", "A designer seeks the pair with the strongest conventional hue contrast, such as blue and orange. How are the hues related?", "Opposite one another on the colour wheel", ["Beside one another on the wheel", "At equal intervals as a triad", "At the same hue with different values"], "Complementary hues lie opposite one another on the colour wheel and create strong contrast."),
    art_card("Colour", "Colour relationships", "What describes an analogous colour scheme?", "A palette uses blue, blue-green, and green, neighbouring hues. What kind of scheme is this?", "Analogous", ["Complementary", "Monochromatic", "Triadic"], "Analogous colours are adjacent on the colour wheel, such as blue, blue-green, and green."),
    art_card("Principles of design", "Balance", "Which principle concerns the visual distribution of weight in a composition?", "One side of a poster feels heavier than the other. Which design principle should be reconsidered?", "Balance", ["Texture", "Hue", "Contour"], "Balance concerns the distribution of visual weight; it may be symmetrical, asymmetrical, or radial."),
    art_card("Principles of design", "Balance", "What kind of balance radiates from a central point?", "A circular pattern repeats around its centre like spokes. Which type of balance does it show?", "Radial balance", ["Asymmetrical balance", "Linear perspective", "Vertical emphasis"], "Radial balance arranges visual elements around a central point."),
    art_card("Principles of design", "Contrast", "Which principle is created by a marked difference between visual elements?", "A bright yellow form stands against a dark background to make the difference noticeable. Which principle is used?", "Contrast", ["Proportion", "Repetition", "Unity"], "Contrast uses noticeable differences, such as light versus dark, to distinguish or emphasize elements."),
    art_card("Principles of design", "Emphasis", "Which principle establishes a focal point that attracts the viewer's attention?", "A poster makes its title larger and brighter than everything else. Which principle is being applied?", "Emphasis", ["Pattern", "Rhythm", "Scale"], "Emphasis makes one part of a composition dominant or especially noticeable."),
    art_card("Principles of design", "Pattern and rhythm", "What creates a visual pattern?", "A maker repeats the same geometric unit across a border. Which design idea results?", "Repetition of a motif or element", ["Single-point perspective", "Subtractive carving", "Colour value"], "Pattern results from the planned repetition of a motif or other visual element."),
    art_card("Principles of design", "Pattern and rhythm", "What can create visual rhythm in an artwork?", "A sequence of repeated shapes varies in spacing and size, guiding the eye. Which principle is created?", "A repeated or organized visual movement", ["A single isolated shape", "A fixed horizon", "A wet-on-wet wash"], "Visual rhythm organizes repetition or progression so the viewer's eye moves through a composition."),
    art_card("Principles of design", "Proportion", "What does proportion compare in a composition?", "An artist checks whether a head is appropriately sized in relation to a figure's body. Which principle is under study?", "The relative sizes of parts", ["The direction of a line", "The surface texture", "The hue temperature"], "Proportion concerns the size relationships of parts to one another and to the whole."),
    art_card("Perspective", "Linear perspective", "Which technique uses converging lines to suggest depth on a flat surface?", "A road appears to narrow toward the distance in a drawing. Which method creates this effect?", "Linear perspective", ["Collage", "Stippling", "Radial balance"], "Linear perspective uses receding lines and related size cues to represent spatial depth."),
    art_card("Perspective", "Linear perspective", "What does the horizon line usually represent in linear perspective?", "A landscape drawing places the horizon at the level of the observer's eyes. What does that line indicate?", "The viewer's eye level", ["The nearest object's base", "The edge of the paper", "The light source"], "The horizon line corresponds to the viewer's eye level in a perspective drawing."),
    art_card("Perspective", "Linear perspective", "What is a vanishing point?", "Parallel edges of a road appear to meet at one distant point. What is that point called?", "The apparent meeting point of receding parallel lines", ["The point where shading begins", "The centre of radial balance", "The lightest part of a tint"], "A vanishing point is where receding parallel lines appear to converge in linear perspective."),
    art_card("Perspective", "Linear perspective", "What is characteristic of one-point perspective?", "A box is drawn with its front face parallel to the picture plane and its depth lines receding to one point. Which system is used?", "One-point perspective", ["Two-point perspective", "Radial projection", "Atmospheric collage"], "One-point perspective uses a single vanishing point for the receding depth lines."),
    art_card("Drawing techniques", "Hatching", "How is hatching commonly used to create tonal shading?", "An artist fills a shadow with a series of parallel lines. Which drawing technique is this?", "Hatching", ["Stippling", "Sgraffito", "Point perspective"], "Hatching builds tone with repeated parallel lines."),
    art_card("Drawing techniques", "Cross-hatching", "What distinguishes cross-hatching from simple hatching?", "A drawing layers sets of lines that cross at different angles to darken a shadow. Which technique is used?", "Cross-hatching", ["Stippling", "Frottage", "Wash painting"], "Cross-hatching overlays intersecting sets of hatch lines to build darker values."),
    art_card("Drawing techniques", "Stippling", "Which method builds tone mainly from many small dots?", "A student shades a sphere by varying the density of tiny dots. What technique is being used?", "Stippling", ["Hatching", "Carving", "Impasto"], "Stippling creates value and texture through the number and spacing of dots."),
    art_card("Printmaking", "Relief printing", "In relief printing, which areas receive ink?", "A carved block is rolled with ink and pressed onto paper. Which parts normally make the printed marks?", "The raised surface areas", ["Only the carved grooves", "The back of the paper", "The sides of the block"], "Relief printing transfers ink from the raised areas; recessed areas generally do not print."),
    art_card("Printmaking", "Intaglio", "In intaglio printmaking, where is the ink held for printing?", "An engraved metal plate is wiped so ink remains in its incised lines. Which printmaking process is this?", "In recessed lines or grooves", ["Only on raised surfaces", "Only on a stencil", "In the paper fibres before printing"], "Intaglio prints from recessed incised lines that retain ink."),
    art_card("Printmaking", "Stencil printing", "How does a stencil produce an image?", "Ink passes through cut openings while the remaining sheet blocks it. Which printing method is this?", "Stencil printing", ["Intaglio", "Relief carving", "Fresco"], "Stencil printing transfers colour through open areas while the stencil masks the rest."),
    art_card("Sculpture", "Building methods", "What is additive sculpture?", "A sculptor builds a figure by attaching and shaping successive pieces of clay. Which method is being used?", "Additive construction", ["Subtractive carving", "Intaglio printing", "Drypoint etching"], "Additive sculpture forms a work by adding or building material."),
    art_card("Sculpture", "Building methods", "What is subtractive sculpture?", "A sculptor removes stone with chisels until a figure emerges. Which method is used?", "Subtractive carving", ["Additive modelling", "Collage", "Casting a stencil"], "Subtractive sculpture creates a form by removing material from a larger mass."),
    art_card("Sculpture", "Armature", "What is the function of an armature in sculpture?", "A soft-clay figure needs a hidden support to hold its pose. What should the sculptor build?", "An internal supporting framework", ["A colour wheel", "A printing plate", "A surface glaze"], "An armature is a supporting framework that helps hold a sculptural form in position."),
    art_card("Textiles", "Batik", "How does the traditional resist principle work in batik?", "A maker applies wax to selected parts of cloth before dyeing it. What does the wax do?", "Resists dye in the covered areas", ["Makes the cloth shrink uniformly", "Transfers a relief print", "Adds a clay glaze"], "Wax resists dye, preserving covered areas and creating patterned contrast."),
    art_card("Textiles", "Tie-dye", "What is the purpose of tying or binding cloth before dyeing in tie-dye?", "A cloth is knotted tightly before it enters a dye bath. What effect does binding create?", "It resists dye in selected areas", ["It fixes a metal armature", "It makes every area the same colour", "It creates a perspective grid"], "Binding blocks or limits dye penetration in selected areas, producing resist patterns."),
    art_card("Ceramics", "Clay processes", "What is slip in ceramics?", "A potter joins two clay pieces using a spreadable mixture of clay and water. What is this mixture called?", "Slip", ["A kiln shelf", "A glaze firing", "A relief block"], "Slip is a fluid clay-and-water mixture used for joining, decorating, or casting."),
    art_card("Ceramics", "Firing", "Which equipment heats clay to a controlled high temperature?", "A formed clay vessel must be fired so it becomes ceramic. Which equipment is used?", "A kiln", ["A printing press", "An easel", "A spinning wheel"], "A kiln is a high-temperature furnace used to fire clay and ceramic wares."),
    art_card("Ceramics", "Glazing", "What is a ceramic glaze?", "A fired pot receives a glass-forming coating that may add colour and seal its surface. What is the coating called?", "Glaze", ["Slip", "Armature", "Ground"], "A glaze is a glass-forming coating fused to a ceramic surface during firing."),
    art_card("Elements of art", "Space", "What is negative space?", "A designer studies the empty area around and between the letters in a logo. What is that area called?", "Negative space", ["Positive space", "Form", "Value"], "Negative space is the unoccupied area around or between forms; it helps define the positive forms."),
    art_card("Colour", "Colour schemes", "What is a monochromatic colour scheme?", "A painting uses one hue with several lighter and darker variations. Which colour scheme is this?", "Monochromatic", ["Complementary", "Triadic", "Analogous"], "A monochromatic scheme uses variations in value or saturation of a single hue."),
    art_card("Colour", "Colour schemes", "How are the three hues in a conventional triadic scheme related?", "A designer selects three evenly spaced hues on a colour wheel. What scheme results?", "They are spaced approximately equally around the wheel", ["They are all adjacent", "They are one hue plus black and white", "They form one complementary pair only"], "A triadic scheme uses three hues spaced approximately equally around the colour wheel."),
    art_card("Colour", "Colour properties", "Which term names the basic family identity of a colour, such as red or blue?", "A designer distinguishes a colour's basic identity from its lightness and intensity. Which property is this?", "Hue", ["Value", "Texture", "Proportion"], "Hue is the name or identity of a colour, such as red, green, or blue."),
    art_card("Colour", "Colour properties", "What does saturation describe?", "Two reds have similar lightness, but one looks vivid and the other greyed. Which property differs?", "Colour intensity or purity", ["Relative size", "Surface relief", "Perspective depth"], "Saturation describes a colour's intensity or vividness, from vivid to muted."),
    art_card("Drawing", "Tonal modelling", "What is tonal gradation?", "A shaded sphere changes smoothly from light to dark without abrupt bands. What is this transition called?", "A gradual change in value", ["A repeated motif", "A sharp contour only", "A complementary pair"], "Tonal gradation is a gradual transition between values that helps suggest volume or light."),
    art_card("Perspective", "Atmospheric perspective", "How does atmospheric perspective commonly suggest distance?", "A distant hill is painted paler and less detailed than a nearby tree. Which method is being used?", "Atmospheric perspective", ["One-point perspective", "Relief printing", "Cross-hatching"], "Atmospheric perspective uses reduced contrast, detail, and often cooler or paler colour for distant forms."),
    art_card("Drawing", "Foreshortening", "What is foreshortening?", "A limb pointing toward the viewer appears shorter than its actual length. Which drawing effect explains this?", "Foreshortening", ["Hatching", "Pattern", "Symmetrical balance"], "Foreshortening represents a form angled toward the viewer so its apparent length is compressed."),
    art_card("Principles of design", "Hierarchy", "What is visual hierarchy in a design?", "A page's size, contrast, and placement guide readers from a heading to details. Which design idea is operating?", "Visual hierarchy", ["Intaglio", "Tint", "Contour"], "Visual hierarchy organizes elements by prominence so viewers can perceive their order of importance."),
]

MUSIC = [
    art_card("Notation", "Staff", "How many lines are in a standard five-line music staff?", "A learner draws a standard staff before adding notes. How many horizontal lines should it contain?", "Five", ["Four", "Six", "Seven"], "The standard staff has five horizontal lines and four spaces."),
    art_card("Notation", "Clefs", "Which clef is commonly used for higher-pitched parts such as violin?", "A violin part is written in the clef commonly associated with the upper staff. Which clef is it?", "Treble clef", ["Bass clef", "Alto clef", "Tenor clef"], "The treble clef is commonly used for higher-pitched parts, including violin and many melody lines."),
    art_card("Notation", "Clefs", "Which clef is commonly used for lower-pitched parts such as bass guitar?", "A low-register bass part is assigned its usual staff clef. Which clef is selected?", "Bass clef", ["Treble clef", "Soprano clef", "Percussion clef"], "The bass clef is commonly used for lower-pitched parts, including bass instruments."),
    art_card("Notation", "Note values", "In common time, how many beats does a quarter note usually receive?", "In a basic 4/4 exercise, a quarter note represents how many beats?", "One beat", ["Two beats", "Four beats", "Half a beat"], "In common time, the quarter note is the basic one-beat note value."),
    art_card("Notation", "Note values", "In common time, how many beats does a half note usually last?", "A half note is held for how many quarter-note beats in 4/4?", "Two beats", ["One beat", "Three beats", "Four beats"], "A half note lasts two quarter-note beats in common time."),
    art_card("Notation", "Note values", "In common time, how many beats does a whole note usually last?", "A whole note fills how many quarter-note beats in a 4/4 measure?", "Four beats", ["One beat", "Two beats", "Three beats"], "A whole note lasts four quarter-note beats in 4/4."),
    art_card("Notation", "Measures", "What does a barline do in written music?", "A vertical line separates one measure from the next on a score. What is the line called?", "A barline", ["A tie", "A slur", "A ledger line"], "A barline divides the staff into measures or bars."),
    art_card("Notation", "Rests", "What does a rest signify in music notation?", "A performer sees a rest symbol for one beat. What should happen during that beat?", "Silence for the stated duration", ["Play the previous note louder", "Repeat the last bar", "Change to a new key"], "A rest indicates silence for a specified rhythmic duration."),
    art_card("Musical elements", "Tempo", "What does tempo indicate?", "A conductor asks the ensemble to perform more slowly or quickly. Which musical parameter is being changed?", "The speed of the music", ["The loudness only", "The instrument family", "The scale's number of notes"], "Tempo is the speed or pace at which a piece is performed."),
    art_card("Musical elements", "Dynamics", "What do dynamics indicate in a musical performance?", "A score marks a passage soft and then loud. Which musical feature do these markings control?", "Loudness or softness", ["Pitch height", "Tempo only", "The number of beats per bar"], "Dynamics indicate degrees and changes of loudness or softness."),
    art_card("Musical elements", "Pitch", "What is pitch?", "A singer produces one note higher than another. Which musical attribute differs?", "How high or low a sound is", ["How long the sound lasts", "How many performers play", "How fast the beat moves"], "Pitch is the perceived highness or lowness of a sound."),
    art_card("Musical elements", "Rhythm", "What does rhythm organize in music?", "A drummer arranges sounds and silences of different lengths over time. Which musical element is being shaped?", "Durations and patterns of sounds and silences", ["Only the chord names", "The instrument's material", "The concert venue"], "Rhythm organizes durations and patterns of musical sounds and silences."),
    art_card("Musical elements", "Melody", "What is a melody?", "A listener follows a recognizable sequence of pitches as the tune. Which musical element is heard?", "Melody", ["Timbre", "Dynamics", "Meter"], "A melody is an organized succession of pitches perceived as a musical line or tune."),
    art_card("Musical elements", "Harmony", "What does harmony concern in music?", "Several pitches sound together to support a tune. Which musical element describes their relationship?", "Harmony", ["Tempo", "Articulation", "A rest"], "Harmony concerns the combination and relationship of pitches sounding together."),
    art_card("Musical elements", "Beat", "What is the beat in a piece of music?", "Listeners tap their feet to the recurring regular pulse. What are they following?", "The beat", ["The lyrics", "The timbre", "The key signature"], "The beat is the recurring pulse that underlies musical timing."),
    art_card("Notation", "Time signatures", "In a time signature, what does the upper number generally show?", "A score marked 3/4 groups three quarter-note beats in a bar. Which part of the time signature gives the count?", "The upper number", ["The lower number", "The clef", "The key signature"], "The upper number indicates how many notated beat units are grouped in each measure."),
    art_card("Notation", "Time signatures", "What does the lower number in a simple time signature specify?", "In 3/4, the lower 4 indicates the beat unit is a quarter note. Which number supplies that information?", "The lower number", ["The upper number", "The tempo marking", "The number of staff lines"], "The lower number identifies the note value represented by the beat unit in a simple time signature."),
    art_card("Notation", "Time signatures", "How many quarter-note beats are grouped in each measure of 3/4?", "A waltz-like exercise is notated in 3/4. How many quarter-note beats are in a bar?", "Three", ["Two", "Four", "Six"], "In 3/4, the upper 3 specifies three quarter-note beats per measure."),
    art_card("Notation", "Compound meter", "How is 6/8 commonly felt in two-beat compound meter?", "A 6/8 passage groups its six eighth notes into how many main dotted-quarter beats?", "Two", ["Three", "Six", "Four"], "In the common compound-duple reading of 6/8, six eighth notes group into two dotted-quarter beats."),
    art_card("Notation", "Key signatures", "What does a key signature show at the beginning of a staff?", "A score places a set of sharps after the clef, applying them throughout unless changed. What is that set called?", "The key signature", ["A time signature", "A dynamic marking", "A phrase slur"], "A key signature displays the sharps or flats associated with a key, applying across the staff subject to notation rules."),
    art_card("Theory", "Scales", "Which interval pattern defines a natural major scale in whole-step (W) and half-step (H) terms?", "A learner constructs a major scale from its tonic. Which W/H sequence is correct?", "W–W–H–W–W–W–H", ["W–H–W–W–H–W–W", "H–W–W–H–W–W–W", "W–W–W–H–W–H–W"], "The major scale pattern is W–W–H–W–W–W–H."),
    art_card("Theory", "Scales", "Which interval pattern defines the natural minor scale?", "A student builds a natural minor scale without raising its seventh degree. Which W/H sequence is used?", "W–H–W–W–H–W–W", ["W–W–H–W–W–W–H", "H–W–W–W–H–W–W", "W–W–W–H–W–W–H"], "The natural minor scale follows W–H–W–W–H–W–W."),
    art_card("Theory", "Intervals", "How many scale steps separate two notes an octave apart, counting both endpoints?", "A melody moves from one C to the next C above. What is the interval name?", "An octave", ["A fifth", "A third", "A second"], "Two notes with the same letter name in adjacent registers are an octave apart."),
    art_card("Theory", "Intervals", "What is the interval name for a span of five letter names, such as C to G?", "Counting C–D–E–F–G gives which interval between the endpoints?", "A fifth", ["A third", "A sixth", "An octave"], "C to G spans five letter names, so it is a fifth; its exact quality depends on semitones."),
    art_card("Notation", "Accidentals", "What does a sharp sign do to a note?", "A sharp is placed immediately before a note in a measure. How does it alter that note?", "Raises it by one semitone", ["Lowers it by one semitone", "Raises it by one whole tone", "Cancels every key signature"], "A sharp raises the pitch of a note by one semitone, subject to the notation's scope."),
    art_card("Notation", "Accidentals", "What does a flat sign do to a note?", "A flat is placed before a note. How is the note altered?", "Lowers it by one semitone", ["Raises it by one semitone", "Lowers it by one whole tone", "Shortens its duration"], "A flat lowers a note by one semitone, subject to the notation's scope."),
    art_card("Notation", "Accidentals", "What is the function of a natural sign?", "A note has been altered by a sharp earlier in the measure. Which sign restores its unaltered letter pitch?", "Natural sign", ["Sharp sign", "Flat sign", "Fermata"], "A natural sign cancels a prior sharp or flat for that note within the applicable measure."),
    art_card("Dynamics", "Gradual change", "What does crescendo instruct a performer to do?", "A passage marked crescendo should grow gradually in which way?", "Louder", ["Softer", "Slower", "Higher in pitch"], "Crescendo means a gradual increase in loudness."),
    art_card("Dynamics", "Gradual change", "What does diminuendo instruct a performer to do?", "A passage marked diminuendo should gradually become what?", "Softer", ["Louder", "Faster", "More detached"], "Diminuendo (or decrescendo) indicates a gradual decrease in loudness."),
    art_card("Articulation", "Staccato", "How should a staccato note generally be articulated?", "A performer sees staccato dots over a series of notes. How should the notes sound?", "Short and detached", ["Smoothly connected", "Gradually louder", "With a long fermata"], "Staccato indicates short, separated articulation rather than a smoothly connected line."),
    art_card("Articulation", "Legato", "What does legato indicate?", "A singer connects successive notes without gaps. Which articulation best describes this?", "Smoothly connected", ["Short and detached", "Repeated at random", "Gradually softer"], "Legato asks for notes to be performed smoothly and connected."),
    art_card("Rhythm", "Syncopation", "What is syncopation?", "A rhythmic accent falls on a normally weak beat or between beats. What is this effect called?", "Syncopation", ["Augmentation", "Transposition", "Cadence"], "Syncopation places emphasis on weak beats or offbeats, creating rhythmic displacement."),
    art_card("Texture", "Ostinato", "What is an ostinato?", "A bass player repeats the same short rhythmic and melodic figure throughout a section. What is the repeated figure called?", "Ostinato", ["A coda", "A fermata", "A recitative"], "An ostinato is a persistently repeated musical pattern."),
    art_card("Ensemble skills", "Call and response", "What happens in a call-and-response musical texture?", "A lead singer sings a phrase and a group answers it. Which performance pattern is this?", "Call and response", ["Canon", "Solo cadenza", "Through-composition"], "In call and response, one performer or group presents a call answered by another."),
    art_card("Musical elements", "Timbre", "What is timbre?", "A flute and violin play the same pitch at the same loudness but remain distinguishable. Which quality differs?", "Timbre", ["Tempo", "Meter", "Duration"], "Timbre is tone colour, the quality that helps distinguish sound sources even at the same pitch and loudness."),
    art_card("Forms", "Binary form", "What is the basic section layout of binary form?", "A short composition has two principal sections, often labelled A and B. Which form does it use?", "Binary form", ["Ternary form", "Rondo form", "Strophic form"], "Binary form has two main sections, commonly represented as A–B."),
    art_card("Forms", "Ternary form", "What is the usual large-scale layout of ternary form?", "A piece presents A, contrasts with B, and returns to A. Which form is this?", "Ternary form", ["Binary form", "Through-composed form", "Theme and variations"], "Ternary form follows an A–B–A design, with the opening section returning after a contrasting middle."),
    art_card("Forms", "Rondo form", "What is characteristic of rondo form?", "A recurring main theme alternates with contrasting episodes. Which form is being described?", "Rondo form", ["Binary form", "A single cadence", "A scale sequence"], "Rondo form repeatedly returns to a principal theme between contrasting episodes."),
    art_card("Ensembles", "Instrument families", "Which instrument family includes violin, viola, cello, and double bass?", "A violin section is grouped with viola and cello in an orchestra. Which family is it?", "Strings", ["Brass", "Woodwind", "Percussion"], "Violin, viola, cello, and double bass are bowed string instruments."),
    art_card("Ensembles", "Instrument families", "Which family includes flute, oboe, clarinet, and bassoon?", "A clarinet is grouped with flute, oboe, and bassoon in an orchestral family. Which family?", "Woodwind", ["Brass", "Strings", "Keyboard"], "Flute, oboe, clarinet, and bassoon are standard woodwind instruments."),
    art_card("Ensembles", "Instrument families", "Which family includes trumpet, horn, trombone, and tuba?", "A trumpet section is grouped with trombones and tuba. Which family is represented?", "Brass", ["Woodwind", "Strings", "Percussion"], "Trumpet, horn, trombone, and tuba are brass instruments."),
    art_card("Ensembles", "Instrument families", "Which instrument family produces sound mainly by being struck, shaken, or scraped?", "A school ensemble groups drums, cymbals, and xylophone together. Which family is this?", "Percussion", ["Brass", "Strings", "Woodwind"], "Percussion instruments are sounded by striking, shaking, scraping, or similar actions."),
    art_card("Ensembles", "Voices", "Which voice type is generally the highest common adult female range?", "An adult female singer performs the highest usual choral part. Which voice type is this?", "Soprano", ["Alto", "Tenor", "Bass"], "Soprano is generally the highest common adult female voice category."),
    art_card("Ensembles", "Voices", "Which voice type is generally the lowest common adult male range?", "A male singer performs the lowest standard choral part. Which voice type is this?", "Bass", ["Tenor", "Alto", "Soprano"], "Bass is generally the lowest common adult male voice category."),
    art_card("Theory", "Cadences", "Which Roman-numeral progression commonly forms a strong perfect authentic cadence in major?", "A tonal phrase resolves from the dominant triad to the tonic triad. Which progression is this?", "V–I", ["I–IV", "IV–V", "ii–IV"], "A strong authentic cadence commonly resolves dominant harmony (V) to tonic harmony (I)."),
    art_card("Theory", "Transposition", "What does it mean to transpose a melody?", "A performer moves every note of a melody by the same interval while preserving its contour. What is this operation?", "Transposition", ["Inversion", "Augmentation", "Retrograde"], "Transposition shifts all pitches by the same interval while preserving the melodic relationships."),
    art_card("Theory", "Texture", "What is monophonic texture?", "One unaccompanied melodic line is heard at a time. Which texture describes it?", "Monophonic", ["Homophonic", "Polyphonic", "Heterophonic"], "Monophonic texture consists of a single melodic line without independent simultaneous parts."),
    art_card("Theory", "Texture", "What is homophonic texture?", "A melody is supported by chordal accompaniment moving together harmonically. Which texture is this?", "Homophonic", ["Monophonic", "Polyphonic", "Unison-only"], "Homophonic texture features a prominent melody with chordal accompaniment or parts moving in a coordinated rhythm."),
    art_card("Theory", "Texture", "What is polyphonic texture?", "Two or more independent melodic lines sound simultaneously. Which texture is described?", "Polyphonic", ["Monophonic", "Homophonic", "Unison"], "Polyphonic texture combines two or more relatively independent melodic lines."),
    art_card("African music", "Instruments", "Which West African instrument is a plucked bridge harp-lute with strings and a resonating gourd?", "A performer plays a long-necked, plucked West African instrument with a gourd resonator and many strings. Which instrument is it?", "Kora", ["Ocarina", "Shakuhachi", "Concertina"], "The kora is a West African plucked string instrument built with a gourd resonator and a long neck."),
    art_card("African music", "Instruments", "What is a dundun in Yoruba musical practice?", "A Yoruba ensemble uses a double-headed talking drum whose pitch can be varied by squeezing its cords. What is the drum called?", "Dùndún", ["Kora", "Udu", "Mbira"], "The Yoruba dùndún is a tension drum whose pitch can be altered by squeezing its lacing."),
    art_card("African music", "Instruments", "Which Nigerian instrument is a pot-shaped vessel drum traditionally associated with Igbo music?", "A musician strikes the opening and body of a clay vessel drum associated with Igbo traditions. Which instrument is this?", "Udu", ["Kora", "Dùndún", "Agan"], "The udu is a vessel drum associated especially with Igbo music; its pot-like body helps shape its resonant sound."),
]


def make_options(answer, wrong, sequence):
    choices = [answer, *wrong]
    shift = sequence % 4
    choices = choices[shift:] + choices[:shift]
    return {letter: value for letter, value in zip("ABCD", choices)}, "ABCD"[choices.index(answer)]


def question(subject, sequence, card, text, answer, wrong, explanation, difficulty):
    options, correct = make_options(answer, wrong, sequence)
    return {
        "id": f"{subject}{sequence:03d}",
        "subject_id": subject,
        "topic": card["topic"],
        "subtopic": card["subtopic"],
        "year": None,
        "difficulty": difficulty,
        "question_type": "multiple_choice",
        "question": text,
        "options": options,
        "correct_answer": correct,
        "explanation": explanation,
        "marks": 1,
        "source": SOURCE,
        "verification_status": STATUS,
    }


def language_bank(subject, vocab, grammar):
    vocab = build_vocabulary(subject, vocab)
    easy = vocab[:8] + grammar[:7]
    medium = vocab[8:20] + grammar[7:20]
    hard = vocab[20:] + grammar[20:]
    ordered = [(card, "Easy") for card in easy]
    ordered += [(card, "Medium") for card in medium]
    ordered += [(card, "Hard") for card in hard]
    result = []
    for card, difficulty in ordered:
        result.append(question(subject, len(result) + 1, card, card["q1"],
                              card["answer"], card["wrong"], card["explanation"], difficulty))
        explanation2 = card["explanation"]
        if card["topic"] == "Vocabulary":
            explanation2 = f"In standard {subject.title()}, “{card['answer2']}” means “{card['meaning']}”; the other choices have different meanings."
        result.append(question(subject, len(result) + 1, card, card["q2"],
                              card["answer2"], card["wrong2"], explanation2, difficulty))
    return result


def topic_bank(subject, cards):
    result = []
    for index, card in enumerate(cards):
        difficulty = "Easy" if index < 15 else "Medium" if index < 40 else "Hard"
        result.append(question(subject, len(result) + 1, card, card["q1"],
                              card["answer"], card["wrong"], card["explanation"], difficulty))
        result.append(question(subject, len(result) + 1, card, card["q2"],
                              card["answer2"], card["wrong2"], card["explanation"], difficulty))
    return result


def validate(subject, records):
    assert len(records) == 100, f"{subject}: expected 100, got {len(records)}"
    expected = {"id", "subject_id", "topic", "subtopic", "year", "difficulty",
                "question_type", "question", "options", "correct_answer", "explanation",
                "marks", "source", "verification_status"}
    seen = set()
    counts = {"Easy": 0, "Medium": 0, "Hard": 0}
    for i, record in enumerate(records, 1):
        assert set(record) == expected, f"{subject} {i}: incorrect schema fields"
        assert record["id"] == f"{subject}{i:03d}"
        assert record["subject_id"] == subject
        assert record["year"] is None
        assert record["difficulty"] in counts
        counts[record["difficulty"]] += 1
        assert record["question_type"] == "multiple_choice"
        assert isinstance(record["options"], dict) and list(record["options"]) == list("ABCD")
        assert all(isinstance(record["options"][k], str) and record["options"][k].strip() for k in "ABCD")
        assert len(set(record["options"].values())) == 4
        assert record["correct_answer"] in "ABCD"
        assert isinstance(record["explanation"], str) and len(record["explanation"].strip()) >= 20
        assert record["marks"] == 1
        assert record["source"] == SOURCE and record["verification_status"] == STATUS
        normalized = " ".join(record["question"].casefold().split())
        assert normalized not in seen, f"{subject}: duplicate question {record['id']}"
        seen.add(normalized)
        assert record["topic"] and record["subtopic"]
    assert counts == {"Easy": 30, "Medium": 50, "Hard": 20}, f"{subject}: difficulty counts {counts}"


def main():
    banks = {
        "arabic": language_bank("arabic", ARABIC_VOCAB, ARABIC_GRAMMAR),
        "french": language_bank("french", FRENCH_VOCAB, FRENCH_GRAMMAR),
        "igbo": language_bank("igbo", IGBO_VOCAB, IGBO_GRAMMAR),
        "fine_arts": topic_bank("fine_arts", FINE_ARTS),
        "music": topic_bank("music", MUSIC),
    }
    OUT.mkdir(parents=True, exist_ok=True)
    for subject, records in banks.items():
        validate(subject, records)
        path = OUT / f"{subject}.json"
        path.write_text(json.dumps(records, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"{subject}: {len(records)} questions; 30 Easy / 50 Medium / 20 Hard")


if __name__ == "__main__":
    main()
