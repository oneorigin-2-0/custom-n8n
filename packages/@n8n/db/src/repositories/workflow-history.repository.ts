import { Service } from '@n8n/di';
import { DataSource, In, LessThan, Repository } from '@n8n/typeorm';
import { DateUtils } from '@n8n/typeorm/util/DateUtils';
import { GroupedWorkflowHistory, groupWorkflows, RULES } from 'n8n-workflow';

import { WorkflowHistory, WorkflowEntity } from '../entities';
import { WorkflowPublishHistoryRepository } from './workflow-publish-history.repository';

@Service()
export class WorkflowHistoryRepository extends Repository<WorkflowHistory> {
	constructor(
		dataSource: DataSource,
		private readonly workflowPublishHistoryRepository: WorkflowPublishHistoryRepository,
	) {
		super(WorkflowHistory, dataSource.manager);
	}

	async deleteEarlierThan(date: Date) {
		return await this.delete({ createdAt: LessThan(date) });
	}

	/**
	 * Delete workflow history records earlier than a given date, except for current and active workflow versions.
	 */
	async deleteEarlierThanExceptCurrentAndActive(date: Date) {
		const currentVersionIdsSubquery = this.manager
			.createQueryBuilder()
			.subQuery()
			.select('w.versionId')
			.from(WorkflowEntity, 'w')
			.getQuery();

		const activeVersionIdsSubquery = this.manager
			.createQueryBuilder()
			.subQuery()
			.select('w.activeVersionId')
			.from(WorkflowEntity, 'w')
			.where('w.activeVersionId IS NOT NULL')
			.getQuery();

		return await this.manager
			.createQueryBuilder()
			.delete()
			.from(WorkflowHistory)
			.where('createdAt < :date', { date })
			.andWhere(`versionId NOT IN (${currentVersionIdsSubquery})`)
			.andWhere(`versionId NOT IN (${activeVersionIdsSubquery})`)
			.execute();
	}

	private minimumCompactAgeHours = 24;
	private compactingTimeRangeDays = 8;

	makeSkipActiveAndNamedVersionsRule(activeVersions: string[]) {
		return (
			_prev: GroupedWorkflowHistory<WorkflowHistory>,
			next: GroupedWorkflowHistory<WorkflowHistory>,
			// diff: WorkflowDiff<WorkflowHistory['nodes']>,
		): boolean =>
			!!next.to.name || !!next.to.description || activeVersions.includes(next.to.versionId);
	}

	async pruneHistory(now = new Date()): Promise<number> {
		// const { pruneDataMaxAge, pruneDataMaxCount } = this.globalConfig.executions;

		//

		// Find ids of all executions that were stopped longer that pruneDataMaxAge ago
		const endDate = new Date(now);
		endDate.setHours(endDate.getHours() - this.minimumCompactAgeHours);

		const startDate = new Date(now);
		startDate.setHours(endDate.getHours() - this.minimumCompactAgeHours);
		startDate.setDate(startDate.getDate() - this.compactingTimeRangeDays);

		// 1. Get workflows with recent changes

		// const allVersions = await this.manager
		// 	.createQueryBuilder(WorkflowHistory, 'wh')
		// 	.where('wh.createdAt <= :endDate', {
		// 		endDate: DateUtils.mixedDateToUtcDatetimeString(endDate),
		// 	})
		// 	.andWhere('wh.createdAt >= :startDate', {
		// 		startDate: DateUtils.mixedDateToUtcDatetimeString(startDate),
		// 	})
		// 	.orderBy('wh.workflowId', 'ASC')
		// 	.getRawMany<never>();

		const allVersions = await this.manager
			.createQueryBuilder(WorkflowHistory, 'wh')
			.where('wh.createdAt <= :endDate', {
				endDate: DateUtils.mixedDateToUtcDatetimeString(endDate),
			})
			.andWhere('wh.createdAt >= :startDate', {
				startDate: DateUtils.mixedDateToUtcDatetimeString(startDate),
			})
			.orderBy('wh.createdAt', 'ASC')
			.getMany();

		// Group by workflowId
		const groupedByWorkflowId = allVersions.reduce((acc, version) => {
			const workflowId = version.workflowId;
			if (!acc.has(workflowId)) {
				acc.set(workflowId, []);
			}
			acc.get(workflowId)!.push(version);
			return acc;
		}, new Map<string, WorkflowHistory[]>());

		const versionsToDelete = [];
		for (const [workflowId, workflows] of groupedByWorkflowId.entries()) {
			const publishedVersions =
				await this.workflowPublishHistoryRepository.getPublishedVersions(workflowId);
			const grouped = groupWorkflows<WorkflowHistory>(
				workflows,
				[RULES.mergeAdditiveChanges],
				[this.makeSkipActiveAndNamedVersionsRule(publishedVersions.map((x) => x.versionId))],
			);
			for (const group of grouped) {
				for (const wf of group.groupedWorkflows) {
					versionsToDelete.push(wf.versionId);
				}
			}
		}
		await this.delete({ versionId: In(versionsToDelete) });
		return versionsToDelete.length;
	}
}
