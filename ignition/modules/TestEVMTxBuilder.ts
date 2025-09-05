import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const DEFAULT_SIGNER_ADDRESS = "0x83458E8Bf8206131Fe5c05127007FA164c0948A2";

const TestEVMTxBuilderModule = buildModule("TestEVMTxBuilder", (m) => {
  const signerAddress = m.getParameter("signerAddress", DEFAULT_SIGNER_ADDRESS);

  const testEVMTxBuilder = m.contract("TestEVMTxBuilder", [signerAddress]);

  return { testEVMTxBuilder };
});

export default TestEVMTxBuilderModule;
