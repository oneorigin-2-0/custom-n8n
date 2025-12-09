import { createWorkflowHistory, createWorkflowWithHistory, testDb } from '@n8n/backend-test-utils';
import { WorkflowHistoryRepository } from '@n8n/db';
import { Container } from '@n8n/di';
import type { INode } from 'n8n-workflow';
import { v4 as uuid } from 'uuid';

import { createUser } from '../../shared/db/users';

describe('WorkflowHistoryRepository', () => {
	const testNode1 = {
		id: uuid(),
		name: 'testNode1',
		parameters: {},
		type: 'aNodeType',
		typeVersion: 1,
		position: [0, 0],
	} satisfies INode;

	beforeAll(async () => {
		await testDb.init();
	});

	beforeEach(async () => {
		await testDb.truncate(['WorkflowPublishHistory', 'WorkflowHistory', 'WorkflowEntity', 'User']);
	});

	afterAll(async () => {
		await testDb.terminate();
	});

	describe('pruneHistory', () => {
		it('should prune superseded version', async () => {
			const id1 = uuid();
			const id2 = uuid();

			const workflow = await createWorkflowWithHistory({
				versionId: id1,
				nodes: [{ ...testNode1, parameters: { a: 'a' } }],
			});
			await createWorkflowHistory({
				...workflow,
				versionId: uuid(),
				nodes: [{ ...testNode1, parameters: { a: 'ab' } }],
			});
			await createWorkflowHistory({
				...workflow,
				versionId: uuid(),
				nodes: [{ ...testNode1, parameters: { a: 'abc' } }],
			});
			await createWorkflowHistory({
				...workflow,
				versionId: id2,
				nodes: [{ ...testNode1, parameters: { a: 'abcd' } }],
			});

			// ACT
			const repository = Container.get(WorkflowHistoryRepository);
			{
				const result = await repository.pruneHistory(new Date());
				expect(result).toBe(0);

				const history = await repository.find();
				expect(history.length).toBe(4);
			}

			const twoDaysFromNow = new Date();
			twoDaysFromNow.setDate(twoDaysFromNow.getDate() + 2);
			{
				const result = await repository.pruneHistory(twoDaysFromNow);
				expect(result).toBe(2);

				const history = await repository.find();
				expect(history.length).toBe(2);
				expect(history).toEqual([
					expect.objectContaining({ versionId: id1 }),
					expect.objectContaining({ versionId: id2 }),
				]);
			}
		});
	});
});
