import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _Header(),
              SizedBox(height: 20),
              _SearchField(),
              SizedBox(height: 28),
              _ContinueReadingCard(),
              SizedBox(height: 28),
              _SectionTitle(title: 'Categorias'),
              SizedBox(height: 12),
              _CategoryChips(),
              SizedBox(height: 28),
              _SectionTitle(title: 'Recomendados pra você', actionLabel: 'Ver todos'),
              SizedBox(height: 12),
              _BookList(books: _recommended),
              SizedBox(height: 28),
              _SectionTitle(title: 'Mais lidos da semana', actionLabel: 'Ver todos'),
              SizedBox(height: 12),
              _BookList(books: _trending),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const _BottomNav(),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Olá, Eduardo',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'O que você quer ler hoje?',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          _IconButton(icon: Icons.notifications_none_rounded, onTap: () {}),
          const SizedBox(width: 8),
          const CircleAvatar(
            radius: 22,
            backgroundColor: Color(0xFFEADFF5),
            child: Text(
              'E',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 22, color: AppTheme.textPrimary),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEDE7DD)),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: AppTheme.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Buscar livros, autores, gêneros...',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
            ),
            const Icon(Icons.tune_rounded, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _ContinueReadingCard extends StatelessWidget {
  const _ContinueReadingCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2E2148), Color(0xFF5C4B8A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            _BookCover(
              color: const Color(0xFFE0723A),
              title: 'A Revolução\ndos Bichos',
              width: 84,
              height: 120,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Continue lendo',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                          letterSpacing: 0.3,
                        ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'A Revolução dos Bichos',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'George Orwell',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: const LinearProgressIndicator(
                      value: 0.62,
                      minHeight: 6,
                      backgroundColor: Colors.white24,
                      valueColor: AlwaysStoppedAnimation(AppTheme.accent),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '62% • cap. 7 de 10',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.actionLabel});
  final String title;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (actionLabel != null)
            Text(
              actionLabel!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w600,
                  ),
            ),
        ],
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips();

  static const _categories = [
    ('Todos', true),
    ('Ficção', false),
    ('Romance', false),
    ('Tecnologia', false),
    ('Biografia', false),
    ('Filosofia', false),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (label, selected) = _categories[i];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppTheme.textPrimary : AppTheme.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFEDE7DD)),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BookList extends StatelessWidget {
  const _BookList({required this.books});
  final List<_Book> books;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 230,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: books.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          final book = books[i];
          return SizedBox(
            width: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BookCover(
                  color: book.color,
                  title: book.title,
                  width: 120,
                  height: 170,
                ),
                const SizedBox(height: 8),
                Text(
                  book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  book.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BookCover extends StatelessWidget {
  const _BookCover({
    required this.color,
    required this.title,
    required this.width,
    required this.height,
  });

  final Color color;
  final String title;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
            height: 1.15,
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: Color(0xFFEDE7DD))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const [
              _NavItem(icon: Icons.home_rounded, label: 'Início', selected: true),
              _NavItem(icon: Icons.menu_book_rounded, label: 'Biblioteca'),
              _NavItem(icon: Icons.explore_outlined, label: 'Explorar'),
              _NavItem(icon: Icons.person_outline_rounded, label: 'Perfil'),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.textPrimary : AppTheme.textSecondary;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _Book {
  const _Book(this.title, this.author, this.color);
  final String title;
  final String author;
  final Color color;
}

const _recommended = <_Book>[
  _Book('O Hobbit', 'J. R. R. Tolkien', Color(0xFF2F5D3A)),
  _Book('1984', 'George Orwell', Color(0xFF1F2D4A)),
  _Book('Dom Casmurro', 'Machado de Assis', Color(0xFF7A2E2E)),
  _Book('A Metamorfose', 'Franz Kafka', Color(0xFF3B2E5A)),
];

const _trending = <_Book>[
  _Book('Sapiens', 'Yuval N. Harari', Color(0xFFB36A1A)),
  _Book('O Pequeno Príncipe', 'Saint-Exupéry', Color(0xFF2C6E8F)),
  _Book('A Arte da Guerra', 'Sun Tzu', Color(0xFF4A2222)),
  _Book('Mindset', 'Carol Dweck', Color(0xFF5A3D7A)),
];
