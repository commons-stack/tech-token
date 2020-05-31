import { BuidlerRuntimeEnvironment, DeployFunction } from "@nomiclabs/buidler/types";

import { get } from "../accounts";
import { parseEther } from "ethers/utils";

const MNEMONIC = process.env.MNEMONIC || "";
const DEVCHAIN_ACCOUNT_NUM = Number(process.env.DEVCHAIN_ACCOUNT_NUM || "20");
const MOCK_DAI_BALANCE = process.env.MOCK_DAI_BALANCE || "1000000";

const func: DeployFunction = async (bre: BuidlerRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = bre;
  const { deployer } = await getNamedAccounts();
  const { deploy } = deployments;

  await deploy("DAIMock", {
    from: deployer,
    args: [get(MNEMONIC, DEVCHAIN_ACCOUNT_NUM), parseEther(MOCK_DAI_BALANCE)],
  });
};

export default func;
