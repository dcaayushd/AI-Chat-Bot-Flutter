enum ChatMode {
  general('General', 'Everyday questions, ideas, and plans', '', [
    'Plan my day',
    'Explain a concept',
    'Brainstorm ideas',
    'Summarize notes',
  ]),
  writing(
    'Writing',
    'Draft, revise, and find the right tone',
    'Preserve the author’s intent and adapt the tone to the audience. '
        'Offer a polished draft and explain consequential edits when asked.',
    [
      'Draft an email',
      'Improve this paragraph',
      'Outline an article',
      'Make this concise'
    ],
  ),
  coding(
    'Coding',
    'Understand, debug, and review code',
    'Treat the user’s language, framework, and constraints as authoritative. '
        'Show runnable code where appropriate and call out edge cases or assumptions.',
    [
      'Review my code',
      'Explain an error',
      'Write a unit test',
      'Help me refactor'
    ],
  ),
  study(
    'Study',
    'Learn with explanations and practice',
    'Teach in steps using concrete examples. Adapt to the learner’s level '
        'and use short practice questions when helpful.',
    [
      'Quiz me on a topic',
      'Build a study plan',
      'Explain step by step',
      'Make flashcards'
    ],
  );

  const ChatMode(this.label, this.description, this.instruction, this.prompts);

  final String label;
  final String description;
  final String instruction;
  final List<String> prompts;

  static ChatMode fromName(String? name) => values.firstWhere(
        (mode) => mode.name == name,
        orElse: () => general,
      );
}
