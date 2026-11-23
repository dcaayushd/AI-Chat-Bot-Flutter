class StarterPrompt {
  const StarterPrompt(this.title, this.description, this.draft);

  final String title;
  final String description;
  final String draft;
}

enum ChatMode {
  general('General', 'Everyday questions, ideas, and plans', '', [
    StarterPrompt(
      'Plan my day',
      'Build a realistic schedule.',
      'Help me plan my day. Ask about my priorities, fixed appointments, and available time. Then build a schedule with breaks and a first step.',
    ),
    StarterPrompt(
      'Explain a concept',
      'Build intuition with an example.',
      'Help me understand a concept. Ask what it is and what I already know. Give a plain-language explanation, a concrete example, and a question to check my understanding.',
    ),
    StarterPrompt(
      'Brainstorm ideas',
      'Explore options and tradeoffs.',
      'Help me brainstorm options for a goal. Ask about the goal and constraints, then suggest distinct approaches with their tradeoffs and the quickest one to test.',
    ),
    StarterPrompt(
      'Summarize notes',
      'Extract decisions and next steps.',
      'Summarize my notes or attached document. Pull out key points, decisions, open questions, and next steps. Flag details that are unclear. Ask me for the notes if I have not included them.',
    ),
  ]),
  writing(
    'Writing',
    'Draft, revise, and find the right tone',
    'Preserve the author’s intent and adapt the tone to the audience. '
        'Offer a polished draft and explain consequential edits when asked.',
    [
      StarterPrompt(
        'Draft an email',
        'Shape a message for its audience.',
        'Help me draft an email. Ask who will read it, what I want them to do, and the tone I need. Then write a subject line and a clear draft.',
      ),
      StarterPrompt(
        'Improve this paragraph',
        'Sharpen a draft while keeping its voice.',
        'Ask me for a paragraph and its intended audience. Revise it for clarity while keeping the original intent and voice. Point out the most important edit.',
      ),
      StarterPrompt(
        'Outline an article',
        'Organize an argument before drafting.',
        'Help me outline an article. Ask about the topic, reader, and main argument, then propose a section sequence with the purpose of each section.',
      ),
      StarterPrompt(
        'Make this concise',
        'Keep the facts and tighten the wording.',
        'Ask me to paste the text I want to shorten. Produce a tighter version that preserves key facts, commitments, and the intended tone.',
      ),
    ],
  ),
  coding(
    'Coding',
    'Understand, debug, and review code',
    'Treat the user’s language, framework, and constraints as authoritative. '
        'Show runnable code where appropriate and call out edge cases or assumptions.',
    [
      StarterPrompt(
        'Review my code',
        'Find bugs and prioritize fixes.',
        'Review code I share for correctness, maintainability, and edge cases. Ask for the code and expected behavior, then prioritize findings and show targeted fixes.',
      ),
      StarterPrompt(
        'Explain an error',
        'Trace the cause and verify a fix.',
        'Help me understand an error. Ask for the error, the relevant code, and what I expected. Explain the likely cause and propose a small check to verify the fix.',
      ),
      StarterPrompt(
        'Write a unit test',
        'Cover behavior and failure cases.',
        'Help me write unit tests. Ask for the function, expected behavior, and test framework. Cover the normal case, edge cases, and one failure path with runnable examples.',
      ),
      StarterPrompt(
        'Help me refactor',
        'Simplify code while preserving behavior.',
        'Help me refactor code. Ask for the code, its callers, and the behavior to preserve. Suggest the smallest meaningful change and explain how to verify it.',
      ),
    ],
  ),
  study(
    'Study',
    'Learn with explanations and practice',
    'Teach in steps using concrete examples. Adapt to the learner’s level '
        'and use short practice questions when helpful.',
    [
      StarterPrompt(
        'Quiz me on a topic',
        'Practice one question at a time.',
        'Ask for my topic and level, then quiz me one question at a time. Wait for each answer and explain what I got right or missed before moving on.',
      ),
      StarterPrompt(
        'Build a study plan',
        'Schedule practice around a deadline.',
        'Ask what I am studying, my deadline, and how much time I have. Build a study plan that includes spaced review, practice, and checkpoints.',
      ),
      StarterPrompt(
        'Explain step by step',
        'Work through an example together.',
        'Ask what I want to learn and what I already know. Work through an example in small steps, checking my understanding before increasing the difficulty.',
      ),
      StarterPrompt(
        'Make flashcards',
        'Turn material into short recall cards.',
        'Ask for my notes or topic. Make concise flashcards, each with one question and one answer. Include a few cards that test common misunderstandings.',
      ),
    ],
  );

  const ChatMode(this.label, this.description, this.instruction, this.prompts);

  final String label;
  final String description;
  final String instruction;
  final List<StarterPrompt> prompts;

  static ChatMode fromName(String? name) =>
      values.firstWhere((mode) => mode.name == name, orElse: () => general);
}
