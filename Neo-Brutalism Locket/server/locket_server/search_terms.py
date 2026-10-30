"""Words that name each COCO-style search term, and the match of a photo's tags to them.

Shared by the eval scripts and the search service. A term matches when one of its words appears
as a whole word in the photo's tag text (see search_v2).
"""
from __future__ import annotations

import re

SYNONYMS = {
    "person": ["person", "people", "man", "woman", "boy", "girl", "child", "kid", "baby", "player", "men", "women", "children", "skier", "surfer", "skateboarder", "batter", "pitcher", "catcher", "rider", "crowd", "couple", "lady", "guy"],
    "bicycle": ["bicycle", "bike", "bikes", "bicycles"], "car": ["car", "cars", "taxi", "sedan", "suv", "van"],
    "motorcycle": ["motorcycle", "motorbike", "motorcycles", "scooter", "moped"], "airplane": ["airplane", "plane", "aircraft", "jet", "airliner"],
    "bus": ["bus", "buses"], "train": ["train", "locomotive", "trains"], "truck": ["truck", "trucks", "pickup"],
    "boat": ["boat", "boats", "ship", "sailboat", "canoe", "kayak", "yacht"], "traffic light": ["traffic light", "traffic signal", "stoplight"],
    "fire hydrant": ["fire hydrant", "hydrant"], "stop sign": ["stop sign"], "parking meter": ["parking meter"],
    "bench": ["bench", "benches"], "bird": ["bird", "birds", "seagull", "duck", "pigeon", "parrot", "goose", "swan"],
    "cat": ["cat", "cats", "kitten"], "dog": ["dog", "dogs", "puppy"], "horse": ["horse", "horses", "pony"],
    "sheep": ["sheep", "lamb"], "cow": ["cow", "cows", "cattle", "bull", "calf"], "elephant": ["elephant", "elephants"],
    "bear": ["bear", "bears"], "zebra": ["zebra", "zebras"], "giraffe": ["giraffe", "giraffes"],
    "backpack": ["backpack", "rucksack", "bag"], "umbrella": ["umbrella", "umbrellas", "parasol"],
    "handbag": ["handbag", "purse", "bag"], "tie": ["tie", "necktie"], "suitcase": ["suitcase", "luggage", "suitcases"],
    "frisbee": ["frisbee"], "skis": ["ski", "skis"], "snowboard": ["snowboard"], "sports ball": ["ball", "football", "soccer ball", "baseball", "tennis ball", "basketball"],
    "kite": ["kite", "kites"], "baseball bat": ["baseball bat", "bat"], "baseball glove": ["baseball glove", "glove", "mitt"],
    "skateboard": ["skateboard", "skateboards"], "surfboard": ["surfboard", "surfboards", "board"], "tennis racket": ["tennis racket", "racket", "racquet"],
    "bottle": ["bottle", "bottles"], "wine glass": ["wine glass", "wine glasses", "glass"], "cup": ["cup", "cups", "mug"],
    "fork": ["fork", "forks"], "knife": ["knife", "knives"], "spoon": ["spoon", "spoons"], "bowl": ["bowl", "bowls"],
    "banana": ["banana", "bananas"], "apple": ["apple", "apples"], "sandwich": ["sandwich", "sandwiches", "burger"],
    "orange": ["orange", "oranges"], "broccoli": ["broccoli"], "carrot": ["carrot", "carrots"], "hot dog": ["hot dog", "hotdog"],
    "pizza": ["pizza", "pizzas"], "donut": ["donut", "donuts", "doughnut"], "cake": ["cake", "cakes", "cupcake"],
    "chair": ["chair", "chairs", "stool"], "couch": ["couch", "sofa", "couches"], "potted plant": ["potted plant", "plant", "plants", "houseplant"],
    "bed": ["bed", "beds"], "dining table": ["dining table", "table", "tables"], "toilet": ["toilet"],
    "tv": ["tv", "television", "monitor"], "laptop": ["laptop", "laptops", "notebook"], "mouse": ["mouse"],
    "remote": ["remote", "remote control"], "keyboard": ["keyboard"], "cell phone": ["cell phone", "phone", "smartphone", "mobile phone"],
    "microwave": ["microwave"], "oven": ["oven", "stove"], "toaster": ["toaster"], "sink": ["sink"],
    "refrigerator": ["refrigerator", "fridge"], "book": ["book", "books"], "clock": ["clock", "clocks"],
    "vase": ["vase", "vases"], "scissors": ["scissors"], "teddy bear": ["teddy bear", "teddy", "stuffed animal"],
    "hair drier": ["hair dryer", "hair drier", "hairdryer"], "toothbrush": ["toothbrush"],
}


def has_term(text: str, term: str) -> bool:
    """True when the tag text names the term or one of its synonyms (whole words, lower case)."""
    words = SYNONYMS.get(term, [term])
    return any(re.search(rf"\b{re.escape(w)}\b", text) for w in words)
