import "@ton/test-utils";

import { Blockchain, SandboxContract } from '@ton-community/sandbox';
import { toNano } from 'ton-core';
import { Task1 } from '../wrappers/Task1';

describe('Task1', () => {
    let blockchain: Blockchain;
    let task1: SandboxContract<Task1>;

    beforeEach(async () => {
        blockchain = await Blockchain.create();
        task1 = blockchain.openContract(await Task1.fromInit());
        const deployer = await blockchain.treasury('deployer');
        const deployResult = await task1.send(
            deployer.getSender(),
            {
                value: toNano('0.05'),
            },
            {
                $$type: 'Deploy',
                queryId: 0n,
            }
        );
        /*
        expect(deployResult.transactions).toHaveTransaction({
            from: deployer.address,
            to: task1.address,
            deploy: true,
            success: true,
        });
        */
    });

    it.skip('initial 0', async () => {
        let counter = await task1.getCounter();
        expect(counter).toBe(0n);
    });

    it.skip('add 10', async () => {
        const dude = await blockchain.treasury('dude');
        await task1.send(dude.getSender(), {
            value: toNano('0.05')
        }, {
            $$type: 'Add',
            queryId: 0n,
            number: 10n
        });
        let counter = await task1.getCounter();
        expect(counter).toBe(10n);
    })

    it('subtract 10', async () => {
        const dude = await blockchain.treasury('dude');
        await task1.send(dude.getSender(), {
            value: toNano('0.05')
        }, {
            $$type: 'Subtract',
            queryId: 0n,
            number: 20n
        });
        let counter = await task1.getCounter();
        expect(counter).toBe(-20n);
    })
});
