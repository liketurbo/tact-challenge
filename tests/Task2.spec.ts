import "@ton/test-utils";

import { Blockchain, SandboxContract } from '@ton-community/sandbox';
import { toNano } from 'ton-core';
import { Task2 } from '../wrappers/Task2';

describe('Task2', () => {
    let blockchain: Blockchain;
    let task2: SandboxContract<Task2>;

    beforeEach(async () => {
        blockchain = await Blockchain.create();
        const deployer = await blockchain.treasury('deployer');
        task2 = blockchain.openContract(await Task2.fromInit(deployer.address));
        const deployResult = await task2.send(
            deployer.getSender(),
            {
                value: toNano('0.05'),
            },
            {
                $$type: 'Deploy',
                queryId: 0n,
            }
        );
    });

    it('test', async () => {
    });
});

