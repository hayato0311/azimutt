import {describe, expect, test} from "@jest/globals";
import {
    databaseToSourceContent,
    LegacyLayout,
    LegacyOrganization,
    LegacyOrigin,
    legacyParseTableId,
    LegacyPlan,
    LegacyPlanId,
    LegacyProject,
    LegacyProjectJson,
    LegacyProjectRelation,
    LegacyProjectStorage,
    LegacyProjectTable,
    LegacyProjectType,
    LegacyProjectVisibility,
    LegacySource,
    sourceToDatabase,
    Timestamp,
    Uuid,
} from "../index";

describe('legacyProject', () => {
    const uuid: Uuid = '84547c71-bec5-433b-87c7-685f1c9353b2'
    const now: Timestamp = 1663789596755
    const plan: LegacyPlan = {
        id: LegacyPlanId.enum.free,
        name: 'Free plan',
        data_exploration: true,
        colors: true,
        aml: 10,
        schema_export: true,
        ai: true,
        analysis: "snapshot",
        project_export: true,
        projects: 2,
        project_dbs: 2,
        project_layouts: 3,
        layout_tables: 10,
        project_doc: 10,
        project_share: true,
        streak: 0
    }
    const organization: LegacyOrganization = {
        id: uuid,
        slug: 'valid',
        name: 'Valid',
        plan: plan,
        logo: 'https://azimutt.app/images/logo_dark.svg',
        description: 'bla bla bla'
    }
    const origins: LegacyOrigin[] = [{id: uuid, lines: [1, 2]}]
    const table: LegacyProjectTable = {
        schema: 'public',
        table: 'users',
        view: false,
        columns: [{
            name: 'id',
            type: 'uuid',
            nullable: false,
            default: 'uuid()',
            comment: {text: 'user id', origins},
            origins
        }],
        primaryKey: {name: 'users_pk', columns: ['id'], origins},
        uniques: [{name: 'users_id_unique', columns: ['id'], definition: 'unique id', origins}],
        indexes: [{name: 'user_id_index', columns: ['id'], definition: 'index id', origins}],
        checks: [{name: 'user_id_check', columns: ['id'], predicate: 'id NOT NULL', origins}],
        comment: {text: 'users', origins},
        origins
    }
    const relation: LegacyProjectRelation = {
        name: 'group_user_id',
        src: {table: 'public.groups', column: 'user_id'},
        ref: {table: 'public.users', column: 'id'},
        srcCardinality: '1',
        refCardinality: '1',
        origins
    }
    const type: LegacyProjectType = {
        schema: 'public',
        name: 'user_role',
        value: {enum: ['guest', 'admin']},
        origins
    }
    const source: LegacySource = {
        id: uuid,
        name: 'Source',
        kind: {
            kind: 'SqlLocalFile',
            name: 'structure.sql',
            size: 1000,
            modified: now
        },
        content: ['content line'],
        tables: [table],
        relations: [relation],
        types: [type],
        enabled: true,
        createdAt: now,
        updatedAt: now
    }
    const layout: LegacyLayout = {
        tables: [{
            id: 'public.users',
            position: {left: 0, top: 0},
            size: {width: 0, height: 0},
            color: 'red',
            columns: ['id'],
            selected: false,
            collapsed: false
        }],
        createdAt: now,
        updatedAt: now
    }
    const project: LegacyProject = {
        organization,
        id: uuid,
        slug: 'project',
        name: 'Project',
        description: 'a description',
        sources: [source],
        metadata: {'public.users': {notes: 'users notes', columns: {}}},
        layouts: {init: layout},
        settings: {removedTables: 'logs'},
        storage: LegacyProjectStorage.enum.local,
        visibility: LegacyProjectVisibility.enum.none,
        createdAt: now,
        updatedAt: now,
        version: 1
    }

    test('zod full', () => {
        const res: LegacyProject = LegacyProject.parse(project) // make sure parser result is aligned with TS type!
        expect(res).toEqual(project)
    })
    test('zod empty', () => {
        const {description, notes, settings, ...valid}: LegacyProject = {...project}
        const res: LegacyProject = LegacyProject.parse(valid)
        expect(res).toEqual(valid)
    })
    test('project json', () => {
        const {organization, id, storage, visibility, createdAt, updatedAt, ...json} = project
        const valid: LegacyProjectJson = {...json, _type: 'json'}
        const res = LegacyProjectJson.parse(valid)
        expect(res).toEqual(valid)
    })
    test('zod full', () => {
        const res: LegacyProjectTable = LegacyProjectTable.parse(table) // make sure parser result is aligned with TS type!
        expect(res).toEqual(table)
    })
    describe('table', () => {
        test('zod full', () => {
            const res: LegacyProjectTable = LegacyProjectTable.parse(table) // make sure parser result is aligned with TS type!
            expect(res).toEqual(table)
        })
        test('zod empty', () => {
            const {view, primaryKey, uniques, indexes, checks, comment, ...valid}: LegacyProjectTable = {...table}
            const res: LegacyProjectTable = LegacyProjectTable.parse(valid)
            expect(res).toEqual(valid)
        })
        test('zod invalid', () => {
            const {columns, ...invalid} = table
            const res = LegacyProjectTable.safeParse(invalid)
            expect(res.success).toEqual(false)
        })
    })
    describe('relation', () => {
        test('zod full', () => {
            const res: LegacyProjectRelation = LegacyProjectRelation.parse(relation) // make sure parser result is aligned with TS type!
            expect(res).toEqual(relation)
        })
        test('zod invalid', () => {
            const {name, ...invalid} = relation
            const res = LegacyProjectRelation.safeParse(invalid)
            expect(res.success).toEqual(false)
        })
        test('zod backward compatible without cardinality', () => {
            const {srcCardinality, refCardinality, ...legacy} = relation
            const res = LegacyProjectRelation.parse(legacy)
            expect(res).toEqual(legacy)
        })
        test('zod rejects invalid cardinality', () => {
            const res = LegacyProjectRelation.safeParse({...relation, srcCardinality: 'many'})
            expect(res.success).toEqual(false)
        })
        test('zod remains strict with unknown keys', () => {
            const res = LegacyProjectRelation.safeParse({...relation, cardinality: '1'})
            expect(res.success).toEqual(false)
        })
        test('round-trips cardinality through source conversion', () => {
            const database = sourceToDatabase(source)
            expect(database.relations?.[0].src.cardinality).toEqual('1')
            expect(database.relations?.[0].ref.cardinality).toEqual('1')
            expect(databaseToSourceContent(database).relations[0]).toMatchObject({
                srcCardinality: '1',
                refCardinality: '1'
            })
        })
        test('infers missing cardinality from a single-column unique', () => {
            const groups: LegacyProjectTable = {
                schema: 'public',
                table: 'groups',
                columns: [{name: 'user_id', type: 'uuid'}],
                uniques: [{name: 'groups_user_id_key', columns: ['user_id']}]
            }
            const legacyRelation = {...relation, srcCardinality: undefined, refCardinality: undefined}
            const database = sourceToDatabase({...source, tables: [...source.tables, groups], relations: [legacyRelation]})
            expect(database.relations?.[0].src.cardinality).toEqual('1')
        })
        test('does not infer from a composite unique', () => {
            const groups: LegacyProjectTable = {
                schema: 'public',
                table: 'groups',
                columns: [{name: 'user_id', type: 'uuid'}, {name: 'tenant_id', type: 'uuid'}],
                uniques: [{name: 'groups_tenant_user_key', columns: ['tenant_id', 'user_id']}]
            }
            const legacyRelation = {...relation, srcCardinality: undefined, refCardinality: undefined}
            const database = sourceToDatabase({...source, tables: [...source.tables, groups], relations: [legacyRelation]})
            expect(database.relations?.[0].src.cardinality).toBeUndefined()
        })
        test('infers missing cardinality from a single-column primary key', () => {
            const groups: LegacyProjectTable = {
                schema: 'public',
                table: 'groups',
                columns: [{name: 'user_id', type: 'uuid'}],
                primaryKey: {name: 'groups_pkey', columns: ['user_id']}
            }
            const legacyRelation = {...relation, srcCardinality: undefined, refCardinality: undefined}
            const database = sourceToDatabase({...source, tables: [...source.tables, groups], relations: [legacyRelation]})
            expect(database.relations?.[0].src.cardinality).toEqual('1')
        })
    })
    describe('type', () => {
        test('zod full', () => {
            const res: LegacyProjectType = LegacyProjectType.parse(type) // make sure parser result is aligned with TS type!
            expect(res).toEqual(type)
        })
        test('zod value definition', () => {
            const valid: LegacyProjectType = {...type, value: {definition: 'my type'}}
            const res: LegacyProjectType = LegacyProjectType.parse(valid)
            expect(res).toEqual(valid)
        })
        test('zod invalid', () => {
            const {name, ...invalid} = type
            const res = LegacyProjectType.safeParse(invalid)
            expect(res.success).toEqual(false)
        })
    })
    describe('source', () => {
        test('zod full', () => {
            const res: LegacySource = LegacySource.parse(source) // make sure parser result is aligned with TS type!
            expect(res).toEqual(source)
        })
        test('zod empty', () => {
            const {types, enabled, ...valid}: LegacySource = {...source}
            const res: LegacySource = LegacySource.parse(valid)
            expect(res).toEqual(valid)
        })
        test('zod remote source', () => {
            const valid: LegacySource = {
                ...source,
                kind: {kind: 'SqlRemoteFile', url: 'https://azimutt.app/elm/samples/basic.sql', size: 1000}
            }
            const res: LegacySource = LegacySource.parse(valid)
            expect(res).toEqual(valid)
        })
        test('zod user source', () => {
            const valid: LegacySource = {...source, kind: {kind: 'AmlEditor'}}
            const res: LegacySource = LegacySource.parse(valid)
            expect(res).toEqual(valid)
        })
        test('zod invalid', () => {
            const {kind, ...invalid} = source
            const res = LegacySource.safeParse(invalid)
            expect(res.success).toEqual(false)
        })
    })
    describe('layout', () => {
        test('zod full', () => {
            const res: LegacyLayout = LegacyLayout.parse(layout) // make sure parser result is aligned with TS type!
            expect(res).toEqual(layout)
        })
        test('zod invalid', () => {
            const {tables, ...invalid} = layout
            const res = LegacyLayout.safeParse(invalid)
            expect(res.success).toEqual(false)
        })
    })
    describe('organization', () => {
        test('zod full', () => {
            const res: LegacyOrganization = LegacyOrganization.parse(organization) // make sure parser result is aligned with TS type!
            expect(res).toEqual(organization)
        })
        test('zod empty', () => {
            const valid: LegacyOrganization = {...organization, description: undefined}
            const res: LegacyOrganization = LegacyOrganization.parse(valid)
            expect(res).toEqual(valid)
        })
        test('zod invalid', () => {
            const {slug, ...invalid} = organization
            const res = LegacyOrganization.safeParse(invalid)
            expect(res.success).toEqual(false)
        })
    })
    test('legacyParseTableId should work', () => {
        expect(legacyParseTableId('public.users')).toEqual({schema: 'public', table: 'users'})
        expect(legacyParseTableId('.users')).toEqual({schema: '', table: 'users'})
        expect(legacyParseTableId('users')).toEqual({schema: '', table: 'users'})
        expect(legacyParseTableId('')).toEqual({schema: '', table: ''})
        expect(legacyParseTableId('a.b.c')).toEqual({schema: 'a', table: 'b'})
    })
})
