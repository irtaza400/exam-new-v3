import json
import os


def test_recipe_exists_and_valid_json():
    assert os.path.exists("data/approved_recipe.json")
    with open("data/approved_recipe.json") as f:
        data = json.load(f)
    assert "recipe_id" in data
