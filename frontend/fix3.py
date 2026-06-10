#!/usr/bin/env python3
import os

BASE = os.path.expanduser(
    "~/Downloads/Last_Ham/final/Smart_PDF/frontend/lib/pages"
)

def read(fname):
    with open(os.path.join(BASE, fname), 'r', encoding='utf-8') as f:
        return f.read()

def write(fname, src):
    with open(os.path.join(BASE, fname), 'w', encoding='utf-8') as f:
        f.write(src)
    print(f"✅  Fixed: {fname}")

PIMP = "import 'widgets/particles_painter.dart';"

def add_import(src, imp):
    if imp in src:
        return src
    lines = src.split('\n')
    last = 0
    for i, l in enumerate(lines):
        if l.strip().startswith('import '):
            last = i
    lines.insert(last + 1, imp)
    return '\n'.join(lines)

# ══════════════════════════════════════════════════════════════
# sign_up_page — replace Container child with Stack(SafeArea+Particles)
# Original structure:
#   Container(
#     ...decoration...
#     child: SafeArea(
#       child: Padding(vertical:24,
#         child: Column(mainAxisSize:min, children:[...])
#       )
#     )
#   )
# New structure:
#   Container(
#     ...decoration...
#     child: Stack(children:[
#       SafeArea(bottom:false, child: Padding(...Column(...))),
#       Positioned.fill(IgnorePointer(ClipRRect(ParticlesLayer())))
#     ])
#   )
# ══════════════════════════════════════════════════════════════
def fix_sign_up():
    src = read('sign_up_page.dart.bak')
    src = add_import(src, PIMP)

    OLD = (
        "                            child: SafeArea(\n"
        "                              child: Padding(\n"
        "                                padding: const EdgeInsets.symmetric(vertical: 24),\n"
        "                                child: Column(\n"
        "                                  mainAxisSize: MainAxisSize.min,\n"
        "                                  children: ["
    )
    NEW = (
        "                            child: Stack(\n"
        "                              children: [\n"
        "                                SafeArea(\n"
        "                                  bottom: false,\n"
        "                                  child: Padding(\n"
        "                                    padding: const EdgeInsets.symmetric(vertical: 24),\n"
        "                                    child: Column(\n"
        "                                      mainAxisSize: MainAxisSize.min,\n"
        "                                      children: ["
    )

    if OLD not in src:
        print("⚠️  sign_up: pattern not found")
        return

    src = src.replace(OLD, NEW, 1)

    # Now find where that Column closes — it ends with:
    #   const SizedBox(height: 16),   ← last item before ],
    # Then:    ],   Column children end
    #         ),   Column
    #        ),    Padding
    #       ),     SafeArea
    #     ),       Container child
    #   ),         Container  ← we need to insert Stack closing here

    # The sign_up header ends before "/// ===== Form ====="
    # In the bak file:
    #   "                          ),\n"   ← Container close
    #   "\n"
    #   "                        /// ===== Form ====="
    # After our patch the indentation shifts, so we match on content
    OLD_END = (
        "                                    const SizedBox(height: 16),\n"
        "                                  ],\n"
        "                                ),\n"
        "                              ),\n"
        "                            ),\n"
        "                          ),\n"
        "\n"
        "                        /// ===== Form ====="
    )
    NEW_END = (
        "                                    const SizedBox(height: 16),\n"
        "                                      ],\n"   # Column children
        "                                    ),\n"     # Column
        "                                  ),\n"       # Padding
        "                                ),\n"         # SafeArea
        "                                Positioned.fill(\n"
        "                                  child: IgnorePointer(\n"
        "                                    child: ClipRRect(\n"
        "                                      borderRadius: const BorderRadius.only(\n"
        "                                        bottomLeft: Radius.circular(40),\n"
        "                                        bottomRight: Radius.circular(40),\n"
        "                                      ),\n"
        "                                      child: const ParticlesLayer(count: 16),\n"
        "                                    ),\n"
        "                                  ),\n"
        "                                ),\n"
        "                              ],\n"           # Stack children
        "                            ),\n"             # Stack
        "                          ),\n"               # Container
        "\n"
        "                        /// ===== Form ====="
    )

    if OLD_END not in src:
        print("⚠️  sign_up: end pattern not found")
        return

    src = src.replace(OLD_END, NEW_END, 1)
    write('sign_up_page.dart', src)


# ══════════════════════════════════════════════════════════════
# home_page drawer — wrap Container child (SafeArea) with Stack
# Original:
#   Container(
#     ...decoration...
#     child: SafeArea(
#       child: Padding(fromLTRB(24,40,24,24),
#         child: Column(crossAxisAlignment:start, children:[...])
#       )
#     )
#   ),
#   Expanded(child: ListView(
# New:
#   Stack(children:[
#     Container(...child: SafeArea(child: Padding(...Column(...)))),
#     Positioned.fill(IgnorePointer(ParticlesLayer()))
#   ]),
#   Expanded(child: ListView(
# ══════════════════════════════════════════════════════════════
def fix_home_drawer():
    src = read('home_page.dart')
    src = add_import(src, PIMP)

    # Already has particles? skip
    if 'ParticlesLayer' in src:
        print("⚪  home: ParticlesLayer already present")
        return

    OLD = (
        "          Container(\n"
        "            width: double.infinity,\n"
        "            decoration: const BoxDecoration(\n"
        "              gradient: LinearGradient(\n"
        "                begin: Alignment.topLeft,\n"
        "                end: Alignment.bottomRight,\n"
        "                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],\n"
        "              ),\n"
        "            ),\n"
        "            child: SafeArea(\n"
        "              child: Padding(\n"
        "                padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),\n"
        "                child: Column(\n"
        "                  crossAxisAlignment: CrossAxisAlignment.start,\n"
        "                  children: ["
    )
    NEW = (
        "          Stack(\n"
        "            children: [\n"
        "              Container(\n"
        "                width: double.infinity,\n"
        "                decoration: const BoxDecoration(\n"
        "                  gradient: LinearGradient(\n"
        "                    begin: Alignment.topLeft,\n"
        "                    end: Alignment.bottomRight,\n"
        "                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],\n"
        "                  ),\n"
        "                ),\n"
        "                child: SafeArea(\n"
        "                  child: Padding(\n"
        "                    padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),\n"
        "                    child: Column(\n"
        "                      crossAxisAlignment: CrossAxisAlignment.start,\n"
        "                      children: ["
    )

    if OLD not in src:
        print("⚠️  home: drawer pattern not found")
        return

    src = src.replace(OLD, NEW, 1)

    # Close — the drawer Column ends with email Text then:
    #   ],   Column children
    #  ),    Column
    # ),     Padding
    #),      SafeArea
    #),      Container
    # then Expanded(child: ListView(
    OLD_END = (
        "                  ],\n"
        "                ),\n"
        "              ),\n"
        "            ),\n"
        "          ),\n"
        "          Expanded(\n"
        "            child: ListView("
    )
    NEW_END = (
        "                    ],\n"       # Column children
        "                  ),\n"         # Column
        "                ),\n"           # Padding
        "              ),\n"             # SafeArea
        "            ),\n"               # Container
        "              Positioned.fill(\n"
        "                child: IgnorePointer(\n"
        "                  child: const ParticlesLayer(count: 10),\n"
        "                ),\n"
        "              ),\n"
        "            ],\n"               # Stack children
        "          ),\n"                 # Stack
        "          Expanded(\n"
        "            child: ListView("
    )

    if OLD_END not in src:
        print("⚠️  home: drawer end pattern not found")
        # debug: show what's around Expanded
        idx = src.find("          Expanded(\n            child: ListView(")
        if idx > 0:
            print("  Context before Expanded:")
            print(repr(src[idx-200:idx+50]))
        return

    src = src.replace(OLD_END, NEW_END, 1)
    write('home_page.dart', src)


fix_sign_up()
fix_home_drawer()
print("\nDone! Run: flutter run")
