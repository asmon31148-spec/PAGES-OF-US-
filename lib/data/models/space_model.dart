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
    final rawMembers = (json['members'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    if (rawMembers.isEmpty) {
      final creator = json['creator_id'] as String?;
      final partner = json['partner_id'] as String? ?? json['partnerId'] as String?;
      if (creator != null && creator.isNotEmpty) rawMembers.add(creator);
      if (partner != null && partner.isNotEmpty && !rawMembers.contains(partner)) rawMembers.add(partner);
    }

    return SpaceModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? json['space_name'] as String? ?? 'Our Sanctuary',
      pairCode: json['pairCode'] as String? ?? json['pair_code'] as String? ?? '',
      partnerId: json['partnerId'] as String? ?? json['partner_id'] as String?,
      members: rawMembers,
      createdAt: json['createdAt'] as String? ?? json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'pairCode': pairCode,
      'partnerId': partnerId,
      'members': members,
      'createdAt': createdAt,
    };
  }
}
