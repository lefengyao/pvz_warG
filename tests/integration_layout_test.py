"""Contract for a single project with separate dimensional ownership."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


class IntegrationLayoutTest(unittest.TestCase):
    def test_one_project_root(self):
        projects = [p.relative_to(ROOT).as_posix() for p in ROOT.rglob('project.godot')
                    if not any(part in {'.git', '.godot'} for part in p.relative_to(ROOT).parts)]
        self.assertEqual(projects, ['project.godot'])

    def test_game_entries_exist(self):
        for entry in ('2d/scenes/levels/chose_map.tscn',
                      '3d/scenes/maps/front_yard/FrontYard.tscn',
                      '3d/scenes/maps/front_yard/EcsFrontYardDemo.tscn',
                      'shared/src/audio/audiomanager.gd',
                      'addons/ecsmini/runtime/ecs_world.gd'):
            with self.subTest(entry=entry):
                self.assertTrue((ROOT / entry).is_file(), entry)

    def test_one_audio_singleton_and_correct_main(self):
        config = (ROOT / 'project.godot').read_text(encoding='utf-8-sig')
        self.assertIn('run/main_scene="res://2d/scenes/levels/chose_map.tscn"', config)
        self.assertIn('Audiomanager="*res://shared/src/audio/audiomanager.gd"', config)
        self.assertEqual(len(re.findall(r'^Audio\w*="\*', config, re.M | re.I)), 1)

    def test_global_classes_have_one_owner(self):
        classes = {}
        for folder in ('2d', '3d', 'shared', 'addons'):
            for script in (ROOT / folder).rglob('*.gd'):
                for name in re.findall(r'^class_name\s+(\w+)', script.read_text(encoding='utf-8-sig'), re.M):
                    self.assertNotIn(name, classes, f'{name}: {classes.get(name)} / {script}')
                    classes[name] = script

    def test_local_bridge_is_optional(self):
        config = (ROOT / 'project.godot').read_text(encoding='utf-8-sig')
        self.assertNotIn('addons/godot_mcp/', config)
        self.assertNotIn('MCPRuntime=', config)


if __name__ == '__main__':
    unittest.main()
