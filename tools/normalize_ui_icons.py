from pathlib import Path

path = Path('scripts/main.gd')
text = path.read_text(encoding='utf-8')
replacements = {
    '[["☀", 0, "Sun brightness"], ["◐", 1, "Half-moon brightness"], ["●", 2, "Full-moon brightness"]]':
        '[["DAY", 0, "Day brightness"], ["DUSK", 1, "Dusk brightness"], ["NIGHT", 2, "Night brightness"]]',
    '[["←", -1, "A / Walk left"], ["↑", 0, "W / Walk forward"], ["→", 1, "D / Walk right"]]':
        '[["A", -1, "A / Walk left"], ["W", 0, "W / Walk forward"], ["D", 1, "D / Walk right"]]',
}
for old, new in replacements.items():
    if old not in text:
        raise SystemExit(f'Missing expected UI glyph source: {old}')
    text = text.replace(old, new)
text = text.replace('b.custom_minimum_size = Vector2(50, 42)', 'b.custom_minimum_size = Vector2(56, 42)')
text = text.replace('var brightness_button = small_icon_button(str(entry[0]), func(): set_brightness_mode(brightness_index), str(entry[2]))',
                    'var brightness_button = small_icon_button(str(entry[0]), func(): set_brightness_mode(brightness_index), str(entry[2]))\n\t\tbrightness_button.custom_minimum_size.x = 58.0\n\t\tbrightness_button.add_theme_font_size_override("font_size", 10)')
path.write_text(text, encoding='utf-8')
print('Normalized fragile Unicode UI controls in scripts/main.gd')
