class SpaceModel {
  final String id;
  final String name;
  final String pairCode;
  final String? partnerId;
  final List<String> members;
  final String? createdAt;

  SpaceModel({
    required this.id,
    required this.name,
    required this.pairCode,
    this.partnerId,
    required this.members,
    this.createdAt,
  });

  factory SpaceModel.fromJson(Map<String, dynamic> json) {
    List<String> rawMembers = [];
    final membersData = json['members'];
    if (membersData is List) {
      rawMembers = membersData
          .map((e) => e?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    } else if (membersData is Map) {
      rawMembers = membersData.keys
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    final creator = json['creator_id'] as String? ??
        json['creatorId'] as String? ??
        json['createdBy'] as String?;
    final partner = json['partner_id'] as String? ??
        json['partnerId'] as String?;

    if (rawMembers.isEmpty) {
      if (creator != null && creator.isNotEmpty) rawMembers.add(creator);
      if (partner != null && partner.isNotEmpty && !rawMembers.contains(partner)) {
        rawMembers.add(partner);
      }
    } else {
      if (creator != null && creator.isNotEmpty && !rawMembers.contains(creator)) {
        rawMembers.insert(0, creator);
      }
      if (partner != null && partner.isNotEmpty && !rawMembers.contains(partner)) {
        rawMembers.add(partner);
      }
    }

    final name = json['name'] as String? ??
        json['spaceName'] as String? ??
        json['space_name'] as String? ??
        'Our Sanctuary';

    final pairCode = json['pairCode'] as String? ??
        json['pair_code'] as String? ??
        json['code'] as String? ??
        '';

    final id = json['id'] as String? ??
        json['spaceId'] as String? ??
        json['space_id'] as String? ??
        '';

    return SpaceModel(
      id: id,
      name: name,
      pairCode: pairCode,
      partnerId: partner,
      members: rawMembers,
      createdAt: json['createdAt'] as String? ?? json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'spaceName': name,
      'space_name': name,
      'pairCode': pairCode,
      'pair_code': pairCode,
      if (partnerId != null && partnerId!.isNotEmpty) ...{
        'partnerId': partnerId,
        'partner_id': partnerId,
      },
      'members': members,
      'createdAt': createdAt,
      'created_at': createdAt,
    };
  }
}
