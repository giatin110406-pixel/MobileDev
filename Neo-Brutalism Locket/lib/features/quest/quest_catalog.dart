import 'package:neo_brutalism_locket/features/image_engine/style_type.dart';

/// One daily photo quest: what to shoot, the style the photo turns into and
/// the true story behind it.
class Quest {
  const Quest({
    required this.id,
    required this.subject,
    required this.positives,
    required this.style,
    required this.storyTitle,
    required this.story,
    required this.caption,
    required this.emoji,
    this.negatives = const [],
    this.subjectEn,
    this.storyTitleEn,
    this.storyEn,
    this.captionEn,
  });

  final String id;

  /// What to photograph, shown to the user ("một chùm nho").
  final String subject;

  /// Short English descriptions the laptop's CLIP check accepts. They must
  /// include any everyday word for the subject that the server would
  /// otherwise use as a distractor (e.g. "a dog" for a dog quest).
  final List<String> positives;

  /// Look-alikes that must not pass (sent to the check as extra distractors).
  final List<String> negatives;

  /// [StyleType.vanGogh] or [StyleType.pixel8bit].
  final StyleType style;
  final String storyTitle;
  final String story;

  /// Pre-filled post caption, taken from the story (the user can edit it).
  final String caption;
  final String emoji;

  /// The same four texts in English. The Vietnamese ones above are the
  /// original; an English reader gets these (and falls back to Vietnamese only
  /// for a quest that has none yet, which the catalogue test forbids).
  final String? subjectEn;
  final String? storyTitleEn;
  final String? storyEn;
  final String? captionEn;

  String subjectFor({required bool vietnamese}) =>
      vietnamese ? subject : (subjectEn ?? subject);
  String storyTitleFor({required bool vietnamese}) =>
      vietnamese ? storyTitle : (storyTitleEn ?? storyTitle);
  String storyFor({required bool vietnamese}) =>
      vietnamese ? story : (storyEn ?? story);
  String captionFor({required bool vietnamese}) =>
      vietnamese ? caption : (captionEn ?? caption);
}

/// Every quest, in a fixed order (ids are stored, so never rename one).
const questCatalog = <Quest>[
  // ---- Van Gogh ----
  Quest(
    id: 'vg_grapes',
    subject: 'một chùm nho',
    positives: ['a bunch of grapes', 'grapes'],
    negatives: ['blueberries', 'olives'],
    style: StyleType.vanGogh,
    storyTitle: 'Vườn nho đỏ ở Arles (1888)',
    story:
        'Mùa thu năm 1888 ở Arles, Van Gogh vẽ cảnh nông dân hái nho dưới nắng '
        'chiều đỏ rực. Năm 1890, họa sĩ Anna Boch mua bức tranh với giá 400 '
        'franc tại một triển lãm ở Brussels. Đây thường được kể là bức tranh '
        'duy nhất ông bán được lúc còn sống.',
    caption: 'Bức tranh duy nhất Van Gogh bán được lúc sinh thời 🍇',
    emoji: '🍇',
    subjectEn: 'a bunch of grapes',
    storyTitleEn: 'The Red Vineyard at Arles (1888)',
    storyEn:
        'In the autumn of 1888 in Arles, Van Gogh painted farmers picking '
        'grapes under a blazing red evening sun. In 1890 the painter Anna '
        'Boch bought the painting for 400 francs at an exhibition in '
        'Brussels. It is usually told as the only painting he sold in his '
        'lifetime.',
    captionEn: 'The only painting Van Gogh sold in his lifetime 🍇',
  ),
  Quest(
    id: 'vg_sunflower',
    subject: 'một bông hoa hướng dương',
    positives: ['a sunflower', 'sunflowers'],
    style: StyleType.vanGogh,
    storyTitle: 'Hoa hướng dương (1888)',
    story:
        'Tháng 8 năm 1888, Van Gogh vẽ liền bốn bức hoa hướng dương để trang '
        'trí căn phòng dành cho Paul Gauguin, người sắp đến ở cùng ông tại '
        'Ngôi nhà Vàng ở Arles. Hoa héo rất nhanh nên ông vẽ từ sáng sớm, '
        'tranh thủ từng giờ.',
    caption: 'Vẽ thật nhanh trước khi hoa kịp héo 🌻',
    emoji: '🌻',
    subjectEn: 'a sunflower',
    storyTitleEn: 'Sunflowers (1888)',
    storyEn:
        'In August 1888 Van Gogh painted four sunflower pictures in a row '
        'to decorate the room of Paul Gauguin, who was about to move in '
        'with him at the Yellow House in Arles. Flowers wilt very fast, so '
        'he painted from early morning, using every hour.',
    captionEn: 'Paint fast before the flowers wilt 🌻',
  ),
  Quest(
    id: 'vg_bed',
    subject: 'một chiếc giường',
    positives: ['a bed', 'a bedroom'],
    style: StyleType.vanGogh,
    storyTitle: 'Phòng ngủ ở Arles (1888)',
    story:
        'Van Gogh vẽ căn phòng ngủ đơn sơ của mình ở Ngôi nhà Vàng và yêu nó '
        'đến mức vẽ tổng cộng ba phiên bản. Ông viết cho em trai Theo rằng '
        'nhìn bức tranh phải khiến người ta thấy được nghỉ ngơi.',
    caption: 'Căn phòng giản dị đủ để vẽ ba lần 🛏️',
    emoji: '🛏️',
    subjectEn: 'a bed',
    storyTitleEn: 'The Bedroom in Arles (1888)',
    storyEn:
        'Van Gogh painted his simple bedroom in the Yellow House and loved '
        'it so much that he painted three versions of it. He wrote to his '
        'brother Theo that looking at the picture should make people feel '
        'rested.',
    captionEn: 'A simple room worth painting three times 🛏️',
  ),
  Quest(
    id: 'vg_shoes',
    subject: 'một đôi giày',
    positives: ['a shoe', 'a pair of shoes', 'boots', 'sneakers'],
    style: StyleType.vanGogh,
    storyTitle: 'Một đôi giày (1886)',
    story:
        'Ở Paris, Van Gogh mua một đôi ủng cũ ở chợ đồ cũ rồi vẽ chúng nghiêm '
        'túc như vẽ chân dung. Đôi giày mòn vẹt ấy gợi lên cuộc sống lao động '
        'vất vả mà ông luôn trân trọng.',
    caption: 'Đôi giày cũ cũng đáng được vẽ chân dung 👞',
    emoji: '👞',
    subjectEn: 'a pair of shoes',
    storyTitleEn: 'A Pair of Shoes (1886)',
    storyEn:
        'In Paris, Van Gogh bought a pair of old boots at a flea market and '
        'painted them as seriously as a portrait. Those worn-out shoes '
        'recall the hard working life he always respected.',
    captionEn: 'Old shoes deserve a portrait too 👞',
  ),
  Quest(
    id: 'vg_chair',
    subject: 'một chiếc ghế',
    positives: ['a chair', 'a wooden chair', 'a stool'],
    style: StyleType.vanGogh,
    storyTitle: 'Chiếc ghế của Van Gogh (1888)',
    story:
        'Cuối năm 1888, khi sống cùng Gauguin ở Arles, Van Gogh vẽ chiếc ghế '
        'gỗ mộc mạc của mình với tẩu thuốc đặt trên mặt ghế, rồi vẽ thêm chiếc '
        'ghế bành sang trọng hơn của Gauguin. Hai chiếc ghế như hai bức chân '
        'dung của hai con người rất khác nhau.',
    caption: 'Một chiếc ghế cũng có thể là chân dung 🪑',
    emoji: '🪑',
    subjectEn: 'a chair',
    storyTitleEn: 'Van Gogh\'s Chair (1888)',
    storyEn:
        'In late 1888, while living with Gauguin in Arles, Van Gogh painted '
        'his plain wooden chair with his pipe on the seat, then Gauguin\'s '
        'grander armchair. The two chairs are like portraits of two very '
        'different men.',
    captionEn: 'A chair can be a portrait too 🪑',
  ),
  Quest(
    id: 'vg_almond',
    subject: 'một cành hoa',
    positives: [
      'a flowering branch',
      'blossoms on a branch',
      'a branch with flowers',
    ],
    style: StyleType.vanGogh,
    storyTitle: 'Hoa hạnh nhân (1890)',
    story:
        'Đầu năm 1890, Van Gogh vẽ những cành hạnh nhân nở trắng trên nền '
        'trời xanh để mừng cháu trai chào đời. Em bé được Theo đặt theo tên '
        'người bác: Vincent Willem.',
    caption: 'Món quà mừng cháu trai chào đời 🌸',
    emoji: '🌸',
    subjectEn: 'a flowering branch',
    storyTitleEn: 'Almond Blossom (1890)',
    storyEn:
        'In early 1890 Van Gogh painted white almond branches against a '
        'blue sky to celebrate the birth of his nephew. Theo named the baby '
        'after his uncle: Vincent Willem.',
    captionEn: 'A gift to welcome a newborn nephew 🌸',
  ),
  Quest(
    id: 'vg_potato',
    subject: 'củ khoai tây',
    positives: ['potatoes', 'a potato'],
    style: StyleType.vanGogh,
    storyTitle: 'Những người ăn khoai tây (1885)',
    story:
        'Ở làng Nuenen, Hà Lan, Van Gogh vẽ một gia đình nông dân ăn khoai '
        'tây dưới ánh đèn dầu. Ông muốn người xem cảm nhận rằng chính đôi tay '
        'đưa khoai vào đĩa đã đào đất trồng ra chúng. Đây được xem là kiệt tác '
        'lớn đầu tiên của ông.',
    caption: 'Những bàn tay đã trồng ra bữa tối 🥔',
    emoji: '🥔',
    subjectEn: 'a potato',
    storyTitleEn: 'The Potato Eaters (1885)',
    storyEn:
        'In the village of Nuenen in the Netherlands, Van Gogh painted a '
        'farming family eating potatoes by oil lamp. He wanted viewers to '
        'feel that the very hands putting the potatoes on the plate had dug '
        'them from the earth. It is considered his first great masterpiece.',
    captionEn: 'The hands that grew dinner 🥔',
  ),
  Quest(
    id: 'vg_cafe',
    subject: 'một quán cà phê',
    positives: ['a cafe', 'a coffee shop', 'a cafe terrace', 'a cup of coffee'],
    style: StyleType.vanGogh,
    storyTitle: 'Hiên quán cà phê về đêm (1888)',
    story:
        'Van Gogh dựng giá vẽ ngay giữa đêm để vẽ hiên một quán cà phê ở '
        'quảng trường Forum, Arles. Đây là bức tranh đầu tiên ông vẽ bầu trời '
        'đầy sao, và ông tự hào vì vẽ được màn đêm mà không dùng chút màu đen '
        'nào.',
    caption: 'Màn đêm không cần một chút màu đen nào ☕',
    emoji: '☕',
    subjectEn: 'a café',
    storyTitleEn: 'Café Terrace at Night (1888)',
    storyEn:
        'Van Gogh set up his easel in the middle of the night to paint the '
        'terrace of a café on the Place du Forum in Arles. It was his first '
        'painting of a starry sky, and he was proud to have painted the '
        'night without using any black.',
    captionEn: 'A night that needs no black ☕',
  ),
  Quest(
    id: 'vg_bridge',
    subject: 'một cây cầu',
    positives: ['a bridge', 'a footbridge'],
    style: StyleType.vanGogh,
    storyTitle: 'Cầu Langlois ở Arles (1888)',
    story:
        'Van Gogh nhiều lần vẽ chiếc cầu kéo bằng gỗ bắc qua con kênh gần '
        'Arles. Chiếc cầu, dòng kênh và những người phụ nữ giặt đồ bên bờ '
        'khiến ông nhớ về quê hương Hà Lan.',
    caption: 'Một góc Hà Lan giữa miền Nam nước Pháp 🌉',
    emoji: '🌉',
    subjectEn: 'a bridge',
    storyTitleEn: 'The Langlois Bridge at Arles (1888)',
    storyEn:
        'Van Gogh painted the wooden drawbridge over a canal near Arles '
        'several times. The bridge, the canal and the women washing clothes '
        'on the bank reminded him of his homeland, the Netherlands.',
    captionEn: 'A corner of Holland in the south of France 🌉',
  ),
  Quest(
    id: 'vg_boat',
    subject: 'một chiếc thuyền',
    positives: ['a boat', 'a fishing boat', 'a canoe'],
    style: StyleType.vanGogh,
    storyTitle: 'Thuyền trên bãi biển Saintes-Maries (1888)',
    story:
        'Tháng 6 năm 1888, Van Gogh đến làng chài Saintes-Maries-de-la-Mer '
        'bên Địa Trung Hải. Ông phác thảo những chiếc thuyền nhiều màu nằm '
        'trên bãi cát từ sáng sớm, trước khi ngư dân ra khơi, rồi về Arles '
        'mới vẽ thành tranh.',
    caption: 'Những con thuyền chờ ra khơi lúc bình minh ⛵',
    emoji: '⛵',
    subjectEn: 'a boat',
    storyTitleEn: 'Boats on the Beach at Saintes-Maries (1888)',
    storyEn:
        'In June 1888 Van Gogh went to the fishing village of '
        'Saintes-Maries-de-la-Mer on the Mediterranean. He sketched the '
        'colourful boats lying on the sand early in the morning, before the '
        'fishermen set out, and only turned them into a painting back in '
        'Arles.',
    captionEn: 'Boats waiting at dawn to put to sea ⛵',
  ),
  Quest(
    id: 'vg_selfie',
    subject: 'một bức chân dung tự chụp (selfie)',
    positives: ['a selfie', 'a face', 'a person', 'a portrait of a person'],
    style: StyleType.vanGogh,
    storyTitle: 'Hơn 35 bức chân dung tự họa',
    story:
        'Van Gogh vẽ hơn 35 bức chân dung tự họa chỉ trong khoảng mười năm. '
        'Một lý do rất đời thường: ông quá nghèo để thuê người mẫu, nên tự '
        'nhìn vào gương và vẽ chính mình.',
    caption: 'Không có tiền thuê mẫu thì tự làm mẫu 🪞',
    emoji: '🪞',
    subjectEn: 'a self-portrait (selfie)',
    storyTitleEn: 'More than 35 self-portraits',
    storyEn:
        'Van Gogh painted more than 35 self-portraits in about ten years. '
        'The reason was very ordinary: he was too poor to hire a model, so '
        'he looked in the mirror and painted himself.',
    captionEn: 'No money for a model? Be your own 🪞',
  ),
  Quest(
    id: 'vg_field',
    subject: 'một cánh đồng hoặc bãi cỏ',
    positives: [
      'a field',
      'a wheat field',
      'a rice field',
      'a meadow',
      'grass',
    ],
    style: StyleType.vanGogh,
    storyTitle: 'Cánh đồng lúa mì với đàn quạ (1890)',
    story:
        'Đây là một trong những bức tranh cuối cùng của Van Gogh, vẽ ở '
        'Auvers-sur-Oise vào tháng 7 năm 1890. Trong thư gửi Theo, ông kể về '
        'những cánh đồng lúa mì bao la trải dài dưới bầu trời giông bão.',
    caption: 'Cánh đồng bao la dưới bầu trời giông 🌾',
    emoji: '🌾',
    subjectEn: 'a field or meadow',
    storyTitleEn: 'Wheatfield with Crows (1890)',
    storyEn:
        'This is one of Van Gogh\'s last paintings, made in Auvers-sur-Oise '
        'in July 1890. In a letter to Theo he described the vast wheat '
        'fields stretching under a stormy sky.',
    captionEn: 'A vast field under a stormy sky 🌾',
  ),
  Quest(
    id: 'vg_tree',
    subject: 'một cái cây',
    positives: ['a tree', 'a tall tree', 'a cypress tree'],
    style: StyleType.vanGogh,
    storyTitle: 'Cây bách (1889)',
    story:
        'Ở Saint-Rémy, Van Gogh say mê những cây bách cao vút như ngọn lửa '
        'xanh. Ông viết cho Theo rằng đường nét và tỉ lệ của cây bách đẹp như '
        'một cột tháp Ai Cập, và lạ là chưa ai vẽ chúng theo cách ông thấy.',
    caption: 'Cây xanh vươn lên như ngọn lửa 🌲',
    emoji: '🌲',
    subjectEn: 'a tree',
    storyTitleEn: 'Cypresses (1889)',
    storyEn:
        'In Saint-Rémy, Van Gogh was captivated by cypress trees rising '
        'like green flames. He wrote to Theo that their lines and '
        'proportions were as beautiful as an Egyptian obelisk, and '
        'strangely nobody had painted them the way he saw them.',
    captionEn: 'Green reaching up like a flame 🌲',
  ),

  // ---- 8-bit ----
  Quest(
    id: 'px_mushroom',
    subject: 'một cây nấm',
    positives: ['a mushroom', 'mushrooms'],
    style: StyleType.pixel8bit,
    storyTitle: 'Super Mario Bros. (1985)',
    story:
        'Trong Super Mario Bros. trên máy NES, ăn Siêu Nấm giúp Mario to gấp '
        'đôi và chịu thêm được một lần trúng đòn. Trò chơi bán được hơn 40 '
        'triệu bản và giữ kỷ lục game bán chạy nhất suốt hơn hai mươi năm.',
    caption: 'Ăn nấm, to gấp đôi! 🍄',
    emoji: '🍄',
    subjectEn: 'a mushroom',
    storyTitleEn: 'Super Mario Bros. (1985)',
    storyEn:
        'In Super Mario Bros. on the NES, eating a Super Mushroom makes '
        'Mario twice as big and lets him take one more hit. The game sold '
        'more than 40 million copies and held the best-selling game record '
        'for over twenty years.',
    captionEn: 'Eat a mushroom, grow double! 🍄',
  ),
  Quest(
    id: 'px_pizza',
    subject: 'một chiếc bánh pizza',
    positives: ['a pizza', 'a slice of pizza'],
    style: StyleType.pixel8bit,
    storyTitle: 'Pac-Man (1980)',
    story:
        'Tōru Iwatani, cha đẻ Pac-Man, kể rằng ông nghĩ ra hình dáng nhân vật '
        'khi nhìn một chiếc pizza bị lấy mất một miếng. Ông muốn làm một trò '
        'chơi dễ thương về chuyện ăn uống, để cả nữ giới cũng thích đến tiệm '
        'game vốn toàn trò bắn súng.',
    caption: 'Pizza thiếu một miếng = Pac-Man 🍕',
    emoji: '🍕',
    subjectEn: 'a pizza',
    storyTitleEn: 'Pac-Man (1980)',
    storyEn:
        'Tōru Iwatani, the creator of Pac-Man, said he came up with the '
        'character\'s shape while looking at a pizza with a slice missing. '
        'He wanted a cute game about eating, so that women would also enjoy '
        'arcades that were full of shooting games.',
    captionEn: 'Pizza with a slice missing = Pac-Man 🍕',
  ),
  Quest(
    id: 'px_apple',
    subject: 'một quả táo',
    positives: ['an apple', 'apples'],
    style: StyleType.pixel8bit,
    storyTitle: 'Trái cây thưởng trong Pac-Man',
    story:
        'Trong Pac-Man, trái cây thưởng xuất hiện giữa mê cung và càng lên '
        'màn cao càng đáng giá: anh đào 100 điểm, dâu 300, cam 500 và táo tới '
        '700 điểm. Ăn kịp trước khi nó biến mất là bí quyết lên bảng xếp hạng.',
    caption: 'Một quả táo = 700 điểm 🍎',
    emoji: '🍎',
    subjectEn: 'an apple',
    storyTitleEn: 'Pac-Man bonus fruit',
    storyEn:
        'In Pac-Man, bonus fruit appears in the maze and is worth more on '
        'higher levels: cherry 100 points, strawberry 300, orange 500 and '
        'apple up to 700. Eating it before it vanishes is the secret to the '
        'leaderboard.',
    captionEn: 'One apple = 700 points 🍎',
  ),
  Quest(
    id: 'px_controller',
    subject: 'một tay cầm chơi game hoặc điều khiển từ xa',
    positives: ['a game controller', 'a gamepad', 'a remote control'],
    style: StyleType.pixel8bit,
    storyTitle: 'Nút chữ thập D-pad (1982)',
    story:
        'Kỹ sư Gunpei Yokoi của Nintendo tạo ra nút bấm hình chữ thập cho máy '
        'Game & Watch phiên bản Donkey Kong năm 1982. Thiết kế ấy được đưa lên '
        'tay cầm Famicom/NES và trở thành chuẩn mực cho tay cầm chơi game đến '
        'tận hôm nay.',
    caption: 'Nút chữ thập đã thay đổi cách ta chơi game 🎮',
    emoji: '🎮',
    subjectEn: 'a game controller or remote control',
    storyTitleEn: 'The D-pad (1982)',
    storyEn:
        'Nintendo engineer Gunpei Yokoi created the cross-shaped button for '
        'the 1982 Donkey Kong Game & Watch. The design moved to the '
        'Famicom/NES controller and became the standard for game '
        'controllers to this day.',
    captionEn: 'The D-pad changed how we play 🎮',
  ),
  Quest(
    id: 'px_dog',
    subject: 'một chú chó',
    positives: ['a dog', 'a puppy'],
    style: StyleType.pixel8bit,
    storyTitle: 'Duck Hunt (1984)',
    story:
        'Trong Duck Hunt trên máy NES, người chơi dùng súng ánh sáng Zapper để '
        'bắn vịt. Mỗi lần bắn trượt, chú chó săn lại ló lên cười khúc khích, '
        'và ở bản máy nhà thì bạn không thể bắn nó dù muốn đến đâu.',
    caption: 'Chú chó cười nhạo nổi tiếng nhất làng game 🐶',
    emoji: '🐶',
    subjectEn: 'a dog',
    storyTitleEn: 'Duck Hunt (1984)',
    storyEn:
        'In Duck Hunt on the NES, players use the Zapper light gun to shoot '
        'ducks. Each time you miss, the hunting dog pops up and laughs, and '
        'on the home console you cannot shoot it no matter how much you '
        'want to.',
    captionEn: 'The most famous laughing dog in gaming 🐶',
  ),
  Quest(
    id: 'px_bricks',
    subject: 'một bức tường gạch',
    positives: ['a brick wall', 'bricks', 'a wall made of bricks'],
    style: StyleType.pixel8bit,
    storyTitle: 'Breakout (1976)',
    story:
        'Atari giao cho Steve Jobs làm trò phá gạch Breakout, và Jobs nhờ '
        'người bạn Steve Wozniak thiết kế. Wozniak làm xong bản mẫu chỉ trong '
        'khoảng bốn ngày với rất ít chip. Vài năm sau, hai người cùng sáng lập '
        'Apple.',
    caption: 'Phá gạch từng viên một 🧱',
    emoji: '🧱',
    subjectEn: 'a brick wall',
    storyTitleEn: 'Breakout (1976)',
    storyEn:
        'Atari gave Steve Jobs the job of making the brick-breaking game '
        'Breakout, and Jobs asked his friend Steve Wozniak to design it. '
        'Wozniak finished a prototype in about four days using very few '
        'chips. A few years later the two founded Apple.',
    captionEn: 'Breaking bricks one at a time 🧱',
  ),
  Quest(
    id: 'px_ladder',
    subject: 'một cái thang',
    positives: ['a ladder', 'a step ladder'],
    style: StyleType.pixel8bit,
    storyTitle: 'Donkey Kong (1981)',
    story:
        'Mario xuất hiện lần đầu trong Donkey Kong với cái tên Jumpman, leo '
        'thang và nhảy qua thùng gỗ để cứu cô gái. Về sau anh được đặt theo '
        'tên Mario Segale, chủ nhà kho mà chi nhánh Nintendo ở Mỹ thuê.',
    caption: 'Leo thang như Jumpman năm 1981 🪜',
    emoji: '🪜',
    subjectEn: 'a ladder',
    storyTitleEn: 'Donkey Kong (1981)',
    storyEn:
        'Mario first appeared in Donkey Kong as Jumpman, climbing ladders '
        'and jumping over barrels to rescue a lady. He was later named '
        'after Mario Segale, the owner of the warehouse that Nintendo\'s '
        'American branch rented.',
    captionEn: 'Climbing like Jumpman in 1981 🪜',
  ),
  Quest(
    id: 'px_key',
    subject: 'một chiếc chìa khóa',
    positives: ['a key', 'keys', 'a bunch of keys'],
    style: StyleType.pixel8bit,
    storyTitle: 'The Legend of Zelda (1986)',
    story:
        'Shigeru Miyamoto lấy cảm hứng cho Zelda từ những lần khám phá rừng, '
        'hồ và hang động ở vùng quê gần Kyoto hồi nhỏ. Trong game, mỗi chiếc '
        'chìa khóa nhỏ giúp Link mở thêm một cánh cửa trong hầm ngục.',
    caption: 'Mỗi chìa khóa mở ra một cuộc phiêu lưu 🗝️',
    emoji: '🗝️',
    subjectEn: 'a key',
    storyTitleEn: 'The Legend of Zelda (1986)',
    storyEn:
        'Shigeru Miyamoto took inspiration for Zelda from exploring '
        'forests, lakes and caves in the countryside near Kyoto as a child. '
        'In the game, every small key lets Link open another door in a '
        'dungeon.',
    captionEn: 'Every key opens an adventure 🗝️',
  ),
  Quest(
    id: 'px_clock',
    subject: 'một chiếc đồng hồ',
    positives: ['a clock', 'a watch', 'a wall clock', 'an alarm clock'],
    style: StyleType.pixel8bit,
    storyTitle: 'Game & Watch (1980)',
    story:
        'Gunpei Yokoi nảy ra ý tưởng máy chơi game cầm tay Game & Watch khi '
        'thấy một doanh nhân trên tàu Shinkansen bấm máy tính bỏ túi cho đỡ '
        'chán. Đúng như tên gọi, mỗi máy vừa là trò chơi vừa là đồng hồ.',
    caption: 'Vừa là game vừa là đồng hồ ⌚',
    emoji: '⌚',
    subjectEn: 'a clock',
    storyTitleEn: 'Game & Watch (1980)',
    storyEn:
        'Gunpei Yokoi got the idea for the Game & Watch handheld when he '
        'saw a businessman on the Shinkansen pressing a pocket calculator '
        'to pass the time. As the name says, each unit is both a game and a '
        'clock.',
    captionEn: 'Both a game and a clock ⌚',
  ),
  Quest(
    id: 'px_box',
    subject: 'một chiếc hộp',
    positives: ['a box', 'a cardboard box', 'boxes'],
    style: StyleType.pixel8bit,
    storyTitle: 'Tetris (1984)',
    story:
        'Alexey Pajitnov tạo ra Tetris tại Viện Hàn lâm Khoa học Liên Xô ở '
        'Moskva, lấy cảm hứng từ trò xếp hình pentomino. Năm 1989, Tetris đi '
        'kèm máy Game Boy và trở thành một trong những trò chơi phổ biến nhất '
        'mọi thời đại.',
    caption: 'Xếp khối khít từng ô một 📦',
    emoji: '📦',
    subjectEn: 'a box',
    storyTitleEn: 'Tetris (1984)',
    storyEn:
        'Alexey Pajitnov created Tetris at the Soviet Academy of Sciences '
        'in Moscow, inspired by the pentomino puzzle. In 1989 Tetris came '
        'bundled with the Game Boy and became one of the most popular games '
        'of all time.',
    captionEn: 'Stacking blocks to fit, cell by cell 📦',
  ),
  Quest(
    id: 'px_motorbike',
    subject: 'một chiếc xe máy',
    positives: ['a motorbike', 'a motorcycle', 'a scooter'],
    style: StyleType.pixel8bit,
    storyTitle: 'Excitebike (1984)',
    story:
        'Excitebike trên máy NES cho người chơi đua mô-tô vượt địa hình mà '
        'không để máy quá nóng. Đây là một trong những game đầu tiên trên máy '
        'chơi game tại nhà cho phép người chơi tự thiết kế đường đua.',
    caption: 'Tự thiết kế đường đua từ năm 1984 🏍️',
    emoji: '🏍️',
    subjectEn: 'a motorbike',
    storyTitleEn: 'Excitebike (1984)',
    storyEn:
        'Excitebike on the NES lets you race a motorcycle across rough '
        'terrain without letting the engine overheat. It was one of the '
        'first home-console games to let players design their own tracks.',
    captionEn: 'Designing your own track since 1984 🏍️',
  ),
  Quest(
    id: 'px_coin',
    subject: 'một đồng xu',
    positives: ['a coin', 'coins'],
    style: StyleType.pixel8bit,
    storyTitle: 'Đồng xu của Mario',
    story:
        'Trong Super Mario Bros., cứ gom đủ 100 đồng xu là Mario được thêm một '
        'mạng. Những khối dấu chấm hỏi giấu xu và vật phẩm đã trở thành một '
        'trong những biểu tượng quen thuộc nhất của trò chơi điện tử.',
    caption: '100 xu = thêm một mạng 🪙',
    emoji: '🪙',
    subjectEn: 'a coin',
    storyTitleEn: 'Mario\'s coins',
    storyEn:
        'In Super Mario Bros., collecting 100 coins earns Mario an extra '
        'life. The question-mark blocks hiding coins and items became one '
        'of the most recognisable symbols in video games.',
    captionEn: '100 coins = an extra life 🪙',
  ),
  Quest(
    id: 'px_sky',
    subject: 'bầu trời',
    positives: ['the sky', 'clouds', 'a blue sky'],
    style: StyleType.pixel8bit,
    storyTitle: 'Space Invaders (1978)',
    story:
        'Tomohiro Nishikado tạo ra Space Invaders với đàn người ngoài hành '
        'tinh từ trên trời tiến xuống. Phần cứng thời đó yếu, nên càng bị bắn '
        'bớt, đàn quái càng được vẽ nhanh và di chuyển nhanh hơn. Một "lỗi" vô '
        'tình trở thành độ khó tăng dần kinh điển.',
    caption: 'Lũ xâm lăng đến từ bầu trời 👾',
    emoji: '👾',
    subjectEn: 'the sky',
    storyTitleEn: 'Space Invaders (1978)',
    storyEn:
        'Tomohiro Nishikado created Space Invaders with a horde of aliens '
        'marching down from the sky. The hardware of the time was weak, so '
        'the fewer aliens were left, the faster they were drawn and moved. '
        'An accidental "bug" became the classic rising difficulty.',
    captionEn: 'The invaders come from the sky 👾',
  ),
];

Quest? questById(String id) {
  for (final quest in questCatalog) {
    if (quest.id == id) return quest;
  }
  return null;
}

/// The quest for [day] (days since 1970 in Vietnam time) for the user with
/// [seed]. Each user walks the catalog in their own shuffled order, so nobody
/// repeats a quest until they have seen all of them, and two days in a row are
/// never the same quest.
Quest questForDay(int seed, int day, {List<Quest> catalog = questCatalog}) {
  final n = catalog.length;
  final cycle = day ~/ n;
  final order = _shuffled(seed, cycle, n);
  if (cycle > 0 && n > 2) {
    final previousLast = _shuffled(seed, cycle - 1, n).last;
    if (order.first == previousLast) {
      order[0] = order[1];
      order[1] = previousLast;
    }
  }
  return catalog[order[day % n]];
}

/// Fisher-Yates with a small fixed PRNG (mulberry32), so the order is the same
/// on every platform and Dart version.
List<int> _shuffled(int seed, int cycle, int n) {
  var state = (seed ^ (cycle * 0x9E3779B1)) & 0xFFFFFFFF;
  int next(int bound) {
    state = (state + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = state;
    t = ((t ^ (t >> 15)) * (t | 1)) & 0xFFFFFFFF;
    t ^= (t + (((t ^ (t >> 7)) * (t | 61)) & 0xFFFFFFFF)) & 0xFFFFFFFF;
    return ((t ^ (t >> 14)) & 0xFFFFFFFF) % bound;
  }

  final order = List<int>.generate(n, (i) => i);
  for (var i = n - 1; i > 0; i--) {
    final j = next(i + 1);
    final swap = order[i];
    order[i] = order[j];
    order[j] = swap;
  }
  return order;
}
