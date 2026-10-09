"""Tests for the Haustelefon generator:  python -m unittest discover -s generator"""

import copy
import tempfile
import unittest
from pathlib import Path

import yaml

import generate as g

EXAMPLE = Path(__file__).resolve().parent.parent / "haustelefon.example.yaml"


def example_config() -> dict:
    cfg = yaml.safe_load(EXAMPLE.read_text(encoding="utf-8"))
    for ln in cfg["lines"]:
        ln["speedport"]["password"] = "secret-" + ln["id"]
    return cfg


class ValidationTest(unittest.TestCase):
    def test_example_is_valid(self):
        m = g.load_model(example_config())
        self.assertEqual([ln.id for ln in m.lines], ["privat", "firma"])
        self.assertEqual(m.device("handy").line, "privat")
        # Group "buero" expands to its members.
        self.assertEqual(m.lines[1].ring, ["pc", "anna"])

    def test_change_me_password_is_rejected(self):
        cfg = yaml.safe_load(EXAMPLE.read_text(encoding="utf-8"))
        with self.assertRaisesRegex(g.ConfigError, "CHANGE_ME"):
            g.load_model(cfg)

    def test_change_me_device_password_is_rejected(self):
        cfg = example_config()
        cfg["devices"][0]["password"] = "CHANGE_ME"
        with self.assertRaisesRegex(g.ConfigError, "CHANGE_ME"):
            g.load_model(cfg)

    def test_duplicate_extension(self):
        cfg = example_config()
        cfg["devices"][1]["extension"] = 10
        with self.assertRaisesRegex(g.ConfigError, "schon vergeben"):
            g.load_model(cfg)

    def test_emergency_numbers_are_protected(self):
        for ext in (110, 112, 1160, 1180):
            cfg = example_config()
            cfg["devices"][0]["extension"] = ext
            with self.assertRaises(g.ConfigError, msg=str(ext)):
                g.load_model(cfg)

    def test_unknown_ring_target(self):
        cfg = example_config()
        cfg["lines"][0]["ring"] = ["nobody"]
        with self.assertRaisesRegex(g.ConfigError, "nobody"):
            g.load_model(cfg)

    def test_default_line_must_be_allowed(self):
        cfg = example_config()
        cfg["devices"][2]["line"] = "privat"  # anna may only use "firma"
        with self.assertRaisesRegex(g.ConfigError, "Standard-Leitung"):
            g.load_model(cfg)

    def test_home_mode_rings_everyone_by_default(self):
        cfg = example_config()
        del cfg["lines"][0]["ring"]
        m = g.load_model(cfg)
        self.assertEqual(m.lines[0].ring, ["handy", "pc", "anna"])

    def test_office_mode_requires_ring(self):
        cfg = example_config()
        cfg["system"]["mode"] = "office"
        del cfg["lines"][0]["ring"]
        with self.assertRaisesRegex(g.ConfigError, "office"):
            g.load_model(cfg)


class RenderTest(unittest.TestCase):
    def setUp(self):
        self.m = g.load_model(example_config())

    def test_pjsip_has_one_registration_per_line(self):
        conf = g.render_pjsip(self.m)
        self.assertEqual(conf.count("type=registration"), 2)
        self.assertIn("client_uri=sip:**71@speedport.ip", conf)
        self.assertIn("username=nutzer-2@speedport.ip", conf)
        self.assertIn("line=yes", conf)
        self.assertIn("[speedport-identify]", conf)
        # Every device is a WebRTC endpoint with its own credentials.
        self.assertEqual(conf.count("webrtc=yes"), 3)

    def test_inbound_routing_and_line_header(self):
        ext = g.render_extensions(self.m)
        self.assertIn("Dial(PJSIP/handy&PJSIP/pc,45,b(hdr-privat^s^1))", ext)
        self.assertIn("Dial(PJSIP/pc&PJSIP/anna,45,b(hdr-firma^s^1))", ext)
        self.assertIn("Set(PJSIP_HEADER(add,X-Haustelefon-Line)=firma)", ext)
        # Fallback dispatch knows the user and number spellings.
        self.assertIn("exten => **72,1,Goto(line-in-firma,s,1)", ext)
        self.assertIn("exten => 0302222222,1,Goto(line-in-firma,s,1)", ext)
        self.assertIn("exten => +49302222222,1,Goto(line-in-firma,s,1)", ext)

    def test_outbound_line_selection_respects_allowed_lines(self):
        ext = g.render_extensions(self.m)
        handy = ext.split("[dev-handy]")[1].split("[dev-")[0]
        anna = ext.split("[dev-anna]")[1]
        self.assertIn('GotoIf($["${HT_LINE}" = "firma"]?ht_firma)', handy)
        self.assertIn("Dial(PJSIP/${EXTEN}@line-privat,90)", handy)
        # Anna may only use "firma" – no way to reach "privat".
        self.assertNotIn("line-privat", anna)

    def test_internal_extensions_in_every_device_context(self):
        ext = g.render_extensions(self.m)
        for ctx in ("[dev-handy]", "[dev-pc]", "[dev-anna]"):
            body = ext.split(ctx)[1].split("\n[")[0]
            self.assertIn("exten => 10,1,Dial(PJSIP/handy,30)", body)
            self.assertIn("exten => 20,1,Dial(PJSIP/pc&PJSIP/anna,30)", body)

    def test_number_variants(self):
        self.assertEqual(
            g.number_variants("+49 30 1111111"),
            ["+49301111111", "49301111111", "0049301111111", "0301111111"],
        )
        self.assertEqual(g.number_variants("030 1111111")[0], "+49301111111")


class ProvisioningAndSecretsTest(unittest.TestCase):
    def test_code_roundtrip(self):
        m = g.load_model(example_config())
        anna = m.device("anna")
        data = g.decode_provisioning(g.provisioning_code(m, anna))
        self.assertEqual(data["user"], "anna")
        self.assertEqual(data["pass"], anna.password)
        self.assertEqual(data["ws"], "ws://192.168.2.50:8088/ws")
        self.assertEqual([ln["id"] for ln in data["lines"]], ["firma"])
        self.assertIn({"name": "Büro", "ext": "20", "kind": "group"}, data["dir"])
        self.assertNotIn("anna", [x["name"] for x in data["dir"]])

    def test_generated_passwords_are_stable(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            cfg_path = tmp / "haustelefon.yaml"
            cfg_path.write_text(yaml.safe_dump(example_config()), encoding="utf-8")
            args = ["--config", str(cfg_path), "--secrets", str(tmp / "s.yaml"),
                    "--out", str(tmp / "out")]
            self.assertEqual(g.main(args), 0)
            first = (tmp / "out" / "asterisk" / "pjsip.conf").read_text(encoding="utf-8")
            self.assertEqual(g.main(args), 0)
            second = (tmp / "out" / "asterisk" / "pjsip.conf").read_text(encoding="utf-8")
            self.assertEqual(first, second)
            self.assertTrue((tmp / "out" / "provisioning" / "anna.txt").exists())

    def test_explicit_device_password_is_kept(self):
        cfg = example_config()
        cfg["devices"][0]["password"] = "legacy-pass"
        m = g.load_model(copy.deepcopy(cfg))
        self.assertEqual(m.device("handy").password, "legacy-pass")
        self.assertNotIn("handy", m.generated_secrets)


if __name__ == "__main__":
    unittest.main()
