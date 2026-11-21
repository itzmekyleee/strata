// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'note_link.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetNoteLinkCollection on Isar {
  IsarCollection<NoteLink> get noteLinks => this.collection();
}

const NoteLinkSchema = CollectionSchema(
  name: r'NoteLink',
  id: -6251361636569928518,
  properties: {
    r'fromId': PropertySchema(id: 0, name: r'fromId', type: IsarType.long),
    r'toId': PropertySchema(id: 1, name: r'toId', type: IsarType.long),
  },

  estimateSize: _noteLinkEstimateSize,
  serialize: _noteLinkSerialize,
  deserialize: _noteLinkDeserialize,
  deserializeProp: _noteLinkDeserializeProp,
  idName: r'id',
  indexes: {
    r'fromId': IndexSchema(
      id: 3228658487865934197,
      name: r'fromId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'fromId',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
    r'toId': IndexSchema(
      id: -8279023374200033723,
      name: r'toId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'toId',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _noteLinkGetId,
  getLinks: _noteLinkGetLinks,
  attach: _noteLinkAttach,
  version: '3.3.2',
);

int _noteLinkEstimateSize(
  NoteLink object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  return bytesCount;
}

void _noteLinkSerialize(
  NoteLink object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.fromId);
  writer.writeLong(offsets[1], object.toId);
}

NoteLink _noteLinkDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = NoteLink();
  object.fromId = reader.readLong(offsets[0]);
  object.id = id;
  object.toId = reader.readLong(offsets[1]);
  return object;
}

P _noteLinkDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _noteLinkGetId(NoteLink object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _noteLinkGetLinks(NoteLink object) {
  return [];
}

void _noteLinkAttach(IsarCollection<dynamic> col, Id id, NoteLink object) {
  object.id = id;
}

extension NoteLinkQueryWhereSort on QueryBuilder<NoteLink, NoteLink, QWhere> {
  QueryBuilder<NoteLink, NoteLink, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<NoteLink, NoteLink, QAfterWhere> anyFromId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'fromId'),
      );
    });
  }

  QueryBuilder<NoteLink, NoteLink, QAfterWhere> anyToId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'toId'),
      );
    });
  }
}

extension NoteLinkQueryWhere on QueryBuilder<NoteLink, NoteLink, QWhereClause> {
  QueryBuilder<NoteLink, NoteLink, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<NoteLink, NoteLink, QAfterWhereClause> idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<NoteLink, NoteLink, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<NoteLink, NoteLink, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<NoteLink, NoteLink, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<NoteLink, NoteLink, QAfterWhereClause> fromIdEqualTo(
    int fromId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'fromId', value: [fromId]),
      );
    });
  }

  QueryBuilder<NoteLink, NoteLink, QAfterWhereClause> fromIdNotEqualTo(
    int fromId,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'fromId',
                lower: [],
                upper: [fromId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'fromId',
                lower: [fromId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'fromId',
                lower: [fromId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'fromId',
                lower: [],
                upper: [fromId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<NoteLink, NoteLink, QAfterWhereClause> fromIdGreaterThan(
    int fromId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'fromId',
          lower: [fromId],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<NoteLink, NoteLink, QAfterWhereClause> fromIdLessThan(
    int fromId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'fromId',
          lower: [],
          upper: [fromId],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<NoteLink, NoteLink, QAfterWhereClause> fromIdBetween(
    int lowerFromId,
    int upperFromId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'fromId',
          lower: [lowerFromId],
          includeLower: includeLower,
          upper: [upperFromId],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<NoteLink, NoteLink, QAfterWhereClause> toIdEqualTo(int toId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'toId', value: [toId]),
      );
    });
  }

  QueryBuilder<NoteLink, NoteLink, QAfterWhereClause> toIdNotEqualTo(int toId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'toId',
                lower: [],
                upper: [toId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'toId',
                lower: [toId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'toId',
                lower: [toId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'toId',
                lower: [],
                upper: [toId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<NoteLink, NoteLink, QAfterWhereClause> toIdGreaterThan(
    int toId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'toId',
          lower: [toId],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<NoteLink, NoteLink, QAfterWhereClause> toIdLessThan(
    int toId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'toId',
          lower: [],
          upper: [toId],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<NoteLink, NoteLink, QAfterWhereClause> toIdBetween(
    int lowerToId,
    int upperToId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'toId',
          lower: [lowerToId],
          includeLower: includeLower,
          upper: [upperToId],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension NoteLinkQueryFilter
    on QueryBuilder<NoteLink, NoteLink, QFilterCondition> {
  QueryBuilder<NoteLink, NoteLink, QAfterFilterCondition> fromIdEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'fromId', value: value),
      );
    });
  }

  QueryBuilder<NoteLink, NoteLink, QAfterFilterCondition> fromIdGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'fromId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<NoteLink, NoteLink, QAfterFilterCondition> fromIdLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'fromId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<NoteLink, NoteLink, QAfterFilterCondition> fromIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'fromId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<NoteLink, NoteLink, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<NoteLink, NoteLink, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<NoteLink, NoteLink, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<NoteLink, NoteLink, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<NoteLink, NoteLink, QAfterFilterCondition> toIdEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'toId', value: value),
      );
    });
  }

  QueryBuilder<NoteLink, NoteLink, QAfterFilterCondition> toIdGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'toId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<NoteLink, NoteLink, QAfterFilterCondition> toIdLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'toId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<NoteLink, NoteLink, QAfterFilterCondition> toIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'toId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension NoteLinkQueryObject
    on QueryBuilder<NoteLink, NoteLink, QFilterCondition> {}

extension NoteLinkQueryLinks
    on QueryBuilder<NoteLink, NoteLink, QFilterCondition> {}

extension NoteLinkQuerySortBy on QueryBuilder<NoteLink, NoteLink, QSortBy> {
  QueryBuilder<NoteLink, NoteLink, QAfterSortBy> sortByFromId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fromId', Sort.asc);
    });
  }

  QueryBuilder<NoteLink, NoteLink, QAfterSortBy> sortByFromIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fromId', Sort.desc);
    });
  }

  QueryBuilder<NoteLink, NoteLink, QAfterSortBy> sortByToId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'toId', Sort.asc);
    });
  }

  QueryBuilder<NoteLink, NoteLink, QAfterSortBy> sortByToIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'toId', Sort.desc);
    });
  }
}

extension NoteLinkQuerySortThenBy
    on QueryBuilder<NoteLink, NoteLink, QSortThenBy> {
  QueryBuilder<NoteLink, NoteLink, QAfterSortBy> thenByFromId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fromId', Sort.asc);
    });
  }

  QueryBuilder<NoteLink, NoteLink, QAfterSortBy> thenByFromIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fromId', Sort.desc);
    });
  }

  QueryBuilder<NoteLink, NoteLink, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<NoteLink, NoteLink, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<NoteLink, NoteLink, QAfterSortBy> thenByToId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'toId', Sort.asc);
    });
  }

  QueryBuilder<NoteLink, NoteLink, QAfterSortBy> thenByToIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'toId', Sort.desc);
    });
  }
}

extension NoteLinkQueryWhereDistinct
    on QueryBuilder<NoteLink, NoteLink, QDistinct> {
  QueryBuilder<NoteLink, NoteLink, QDistinct> distinctByFromId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fromId');
    });
  }

  QueryBuilder<NoteLink, NoteLink, QDistinct> distinctByToId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'toId');
    });
  }
}

extension NoteLinkQueryProperty
    on QueryBuilder<NoteLink, NoteLink, QQueryProperty> {
  QueryBuilder<NoteLink, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<NoteLink, int, QQueryOperations> fromIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fromId');
    });
  }

  QueryBuilder<NoteLink, int, QQueryOperations> toIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'toId');
    });
  }
}
