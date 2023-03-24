<template>
  <view>
  </view>
</template>

<script>
import { startWifi, stopWifi } from "@/uni_modules/uni-wifi/utssdk/uni.autotest.js";
import { invokeApi } from "D:/source/uni-api/autotest.utils.js";
export default {
  methods: {
    startWifi00: async function startWifi00() {
      const inputs = [function () {
        "";
      }];
      let startWifi00_res;
      try {
        startWifi00_res = await invokeApi(uni.startWifi, true, ...inputs);
      } catch (e) {
        startWifi00_res = {
          _expectError: true,
          _errMsg: getErrMsg(e)
        };
      }
      return {
        res: startWifi00_res
      };
    },
    startWifi01: async function startWifi01() {
      const inputs = [[]];
      let startWifi01_res;
      try {
        startWifi01_res = await invokeApi(uni.startWifi, true, ...inputs);
      } catch (e) {
        startWifi01_res = {
          _expectError: true,
          _errMsg: getErrMsg(e)
        };
      }
      return {
        res: startWifi01_res
      };
    },
    startWifi02: async function startWifi02() {
      const inputs = [new Uint8Array([0, 1]).buffer];
      let startWifi02_res;
      try {
        startWifi02_res = await invokeApi(uni.startWifi, true, ...inputs);
      } catch (e) {
        startWifi02_res = {
          _expectError: true,
          _errMsg: getErrMsg(e)
        };
      }
      return {
        res: startWifi02_res
      };
    },
    startWifi03: async function startWifi03() {
      const inputs = ["abc"];
      let startWifi03_res;
      try {
        startWifi03_res = await invokeApi(uni.startWifi, true, ...inputs);
      } catch (e) {
        startWifi03_res = {
          _expectError: true,
          _errMsg: getErrMsg(e)
        };
      }
      return {
        res: startWifi03_res
      };
    },
    startWifi04: async function startWifi04() {
      const inputs = ["0"];
      let startWifi04_res;
      try {
        startWifi04_res = await invokeApi(uni.startWifi, true, ...inputs);
      } catch (e) {
        startWifi04_res = {
          _expectError: true,
          _errMsg: getErrMsg(e)
        };
      }
      return {
        res: startWifi04_res
      };
    },
    startWifi05: async function startWifi05() {
      const inputs = ["false"];
      let startWifi05_res;
      try {
        startWifi05_res = await invokeApi(uni.startWifi, true, ...inputs);
      } catch (e) {
        startWifi05_res = {
          _expectError: true,
          _errMsg: getErrMsg(e)
        };
      }
      return {
        res: startWifi05_res
      };
    },
    startWifi06: async function startWifi06() {
      const inputs = ["\u6587"];
      let startWifi06_res;
      try {
        startWifi06_res = await invokeApi(uni.startWifi, true, ...inputs);
      } catch (e) {
        startWifi06_res = {
          _expectError: true,
          _errMsg: getErrMsg(e)
        };
      }
      return {
        res: startWifi06_res
      };
    },
    startWifi07: async function startWifi07() {
      const inputs = ["/"];
      let startWifi07_res;
      try {
        startWifi07_res = await invokeApi(uni.startWifi, true, ...inputs);
      } catch (e) {
        startWifi07_res = {
          _expectError: true,
          _errMsg: getErrMsg(e)
        };
      }
      return {
        res: startWifi07_res
      };
    },
    startWifi08: async function startWifi08() {
      const inputs = ["\""];
      let startWifi08_res;
      try {
        startWifi08_res = await invokeApi(uni.startWifi, true, ...inputs);
      } catch (e) {
        startWifi08_res = {
          _expectError: true,
          _errMsg: getErrMsg(e)
        };
      }
      return {
        res: startWifi08_res
      };
    },
    startWifi09: async function startWifi09() {
      const inputs = ["%"];
      let startWifi09_res;
      try {
        startWifi09_res = await invokeApi(uni.startWifi, true, ...inputs);
      } catch (e) {
        startWifi09_res = {
          _expectError: true,
          _errMsg: getErrMsg(e)
        };
      }
      return {
        res: startWifi09_res
      };
    },
    startWifi010: async function startWifi010() {
      const inputs = [";"];
      let startWifi010_res;
      try {
        startWifi010_res = await invokeApi(uni.startWifi, true, ...inputs);
      } catch (e) {
        startWifi010_res = {
          _expectError: true,
          _errMsg: getErrMsg(e)
        };
      }
      return {
        res: startWifi010_res
      };
    },
    startWifi011: async function startWifi011() {
      const inputs = [-1.1];
      let startWifi011_res;
      try {
        startWifi011_res = await invokeApi(uni.startWifi, true, ...inputs);
      } catch (e) {
        startWifi011_res = {
          _expectError: true,
          _errMsg: getErrMsg(e)
        };
      }
      return {
        res: startWifi011_res
      };
    },
    startWifi012: async function startWifi012() {
      const inputs = [-1];
      let startWifi012_res;
      try {
        startWifi012_res = await invokeApi(uni.startWifi, true, ...inputs);
      } catch (e) {
        startWifi012_res = {
          _expectError: true,
          _errMsg: getErrMsg(e)
        };
      }
      return {
        res: startWifi012_res
      };
    },
    startWifi013: async function startWifi013() {
      const inputs = [-0.1];
      let startWifi013_res;
      try {
        startWifi013_res = await invokeApi(uni.startWifi, true, ...inputs);
      } catch (e) {
        startWifi013_res = {
          _expectError: true,
          _errMsg: getErrMsg(e)
        };
      }
      return {
        res: startWifi013_res
      };
    },
    startWifi014: async function startWifi014() {
      const inputs = [0];
      let startWifi014_res;
      try {
        startWifi014_res = await invokeApi(uni.startWifi, true, ...inputs);
      } catch (e) {
        startWifi014_res = {
          _expectError: true,
          _errMsg: getErrMsg(e)
        };
      }
      return {
        res: startWifi014_res
      };
    },
    startWifi015: async function startWifi015() {
      const inputs = [0.1];
      let startWifi015_res;
      try {
        startWifi015_res = await invokeApi(uni.startWifi, true, ...inputs);
      } catch (e) {
        startWifi015_res = {
          _expectError: true,
          _errMsg: getErrMsg(e)
        };
      }
      return {
        res: startWifi015_res
      };
    },
    startWifi016: async function startWifi016() {
      const inputs = [1];
      let startWifi016_res;
      try {
        startWifi016_res = await invokeApi(uni.startWifi, true, ...inputs);
      } catch (e) {
        startWifi016_res = {
          _expectError: true,
          _errMsg: getErrMsg(e)
        };
      }
      return {
        res: startWifi016_res
      };
    },
    startWifi017: async function startWifi017() {
      const inputs = [1.1];
      let startWifi017_res;
      try {
        startWifi017_res = await invokeApi(uni.startWifi, true, ...inputs);
      } catch (e) {
        startWifi017_res = {
          _expectError: true,
          _errMsg: getErrMsg(e)
        };
      }
      return {
        res: startWifi017_res
      };
    },
    startWifi018: async function startWifi018() {
      const inputs = [-9007199254740991];
      let startWifi018_res;
      try {
        startWifi018_res = await invokeApi(uni.startWifi, true, ...inputs);
      } catch (e) {
        startWifi018_res = {
          _expectError: true,
          _errMsg: getErrMsg(e)
        };
      }
      return {
        res: startWifi018_res
      };
    },
    startWifi019: async function startWifi019() {
      const inputs = [9007199254740991];
      let startWifi019_res;
      try {
        startWifi019_res = await invokeApi(uni.startWifi, true, ...inputs);
      } catch (e) {
        startWifi019_res = {
          _expectError: true,
          _errMsg: getErrMsg(e)
        };
      }
      return {
        res: startWifi019_res
      };
    },
    startWifi020: async function startWifi020() {
      const inputs = [true];
      let startWifi020_res;
      try {
        startWifi020_res = await invokeApi(uni.startWifi, true, ...inputs);
      } catch (e) {
        startWifi020_res = {
          _expectError: true,
          _errMsg: getErrMsg(e)
        };
      }
      return {
        res: startWifi020_res
      };
    },
    startWifi021: async function startWifi021() {
      const inputs = [false];
      let startWifi021_res;
      try {
        startWifi021_res = await invokeApi(uni.startWifi, true, ...inputs);
      } catch (e) {
        startWifi021_res = {
          _expectError: true,
          _errMsg: getErrMsg(e)
        };
      }
      return {
        res: startWifi021_res
      };
    },
    stopWifi10: async function stopWifi10() {
      const inputs = [function () {
        "";
      }];
      let stopWifi10_res;
      try {
        stopWifi10_res = await invokeApi(uni.stopWifi, true, ...inputs);
      } catch (e) {
        stopWifi10_res = {
          _expectError: true,
          _errMsg: getErrMsg(e)
        };
      }
      return {
        res: stopWifi10_res
      };
    },
    stopWifi11: async function stopWifi11() {
      const inputs = [[]];
      let stopWifi11_res;
      try {
        stopWifi11_res = await invokeApi(uni.stopWifi, true, ...inputs);
      } catch (e) {
        stopWifi11_res = {
          _expectError: true,
          _errMsg: getErrMsg(e)
        };
      }
      return {
        res: stopWifi11_res
      };
    },
    stopWifi12: async function stopWifi12() {
      const inputs = [new Uint8Array([0, 1]).buffer];
      let stopWifi12_res;
      try {
        stopWifi12_res = await invokeApi(uni.stopWifi, true, ...inputs);
      } catch (e) {
        stopWifi12_res = {
          _expectError: true,
          _errMsg: getErrMsg(e)
        };
      }
      return {
        res: stopWifi12_res
      };
    },
    stopWifi13: async function stopWifi13() {
      const inputs = ["abc"];
      let stopWifi13_res;
      try {
        stopWifi13_res = await invokeApi(uni.stopWifi, true, ...inputs);
      } catch (e) {
        stopWifi13_res = {
          _expectError: true,
          _errMsg: getErrMsg(e)
        };
      }
      return {
        res: stopWifi13_res
      };
    },
    stopWifi14: async function stopWifi14() {
      const inputs = ["0"];
      let stopWifi14_res;
      try {
        stopWifi14_res = await invokeApi(uni.stopWifi, true, ...inputs);
      } catch (e) {
        stopWifi14_res = {
          _expectError: true,
          _errMsg: getErrMsg(e)
        };
      }
      return {
        res: stopWifi14_res
      };
    },
    stopWifi15: async function stopWifi15() {
      const inputs = ["false"];
      let stopWifi15_res;
      try {
        stopWifi15_res = await invokeApi(uni.stopWifi, true, ...inputs);
      } catch (e) {
        stopWifi15_res = {
          _expectError: true,
          _errMsg: getErrMsg(e)
        };
      }
      return {
        res: stopWifi15_res
      };
    },
    stopWifi16: async function stopWifi16() {
      const inputs = ["\u6587"];
      let stopWifi16_res;
      try {
        stopWifi16_res = await invokeApi(uni.stopWifi, true, ...inputs);
      } catch (e) {
        stopWifi16_res = {
          _expectError: true,
          _errMsg: getErrMsg(e)
        };
      }
      return {
        res: stopWifi16_res
      };
    },
    stopWifi17: async function stopWifi17() {
      const inputs = ["/"];
      let stopWifi17_res;
      try {
        stopWifi17_res = await invokeApi(uni.stopWifi, true, ...inputs);
      } catch (e) {
        stopWifi17_res = {
          _expectError: true,
          _errMsg: getErrMsg(e)
        };
      }
      return {
        res: stopWifi17_res
      };
    },
    stopWifi18: async function stopWifi18() {
      const inputs = ["\""];
      let stopWifi18_res;
      try {
        stopWifi18_res = await invokeApi(uni.stopWifi, true, ...inputs);
      } catch (e) {
        stopWifi18_res = {
          _expectError: true,
          _errMsg: getErrMsg(e)
        };
      }
      return {
        res: stopWifi18_res
      };
    },
    stopWifi19: async function stopWifi19() {
      const inputs = ["%"];
      let stopWifi19_res;
      try {
        stopWifi19_res = await invokeApi(uni.stopWifi, true, ...inputs);
      } catch (e) {
        stopWifi19_res = {
          _expectError: true,
          _errMsg: getErrMsg(e)
        };
      }
      return {
        res: stopWifi19_res
      };
    },
    stopWifi110: async function stopWifi110() {
      const inputs = [";"];
      let stopWifi110_res;
      try {
        stopWifi110_res = await invokeApi(uni.stopWifi, true, ...inputs);
      } catch (e) {
        stopWifi110_res = {
          _expectError: true,
          _errMsg: getErrMsg(e)
        };
      }
      return {
        res: stopWifi110_res
      };
    },
    stopWifi111: async function stopWifi111() {
      const inputs = [-1.1];
      let stopWifi111_res;
      try {
        stopWifi111_res = await invokeApi(uni.stopWifi, true, ...inputs);
      } catch (e) {
        stopWifi111_res = {
          _expectError: true,
          _errMsg: getErrMsg(e)
        };
      }
      return {
        res: stopWifi111_res
      };
    },
    stopWifi112: async function stopWifi112() {
      const inputs = [-1];
      let stopWifi112_res;
      try {
        stopWifi112_res = await invokeApi(uni.stopWifi, true, ...inputs);
      } catch (e) {
        stopWifi112_res = {
          _expectError: true,
          _errMsg: getErrMsg(e)
        };
      }
      return {
        res: stopWifi112_res
      };
    },
    stopWifi113: async function stopWifi113() {
      const inputs = [-0.1];
      let stopWifi113_res;
      try {
        stopWifi113_res = await invokeApi(uni.stopWifi, true, ...inputs);
      } catch (e) {
        stopWifi113_res = {
          _expectError: true,
          _errMsg: getErrMsg(e)
        };
      }
      return {
        res: stopWifi113_res
      };
    },
    stopWifi114: async function stopWifi114() {
      const inputs = [0];
      let stopWifi114_res;
      try {
        stopWifi114_res = await invokeApi(uni.stopWifi, true, ...inputs);
      } catch (e) {
        stopWifi114_res = {
          _expectError: true,
          _errMsg: getErrMsg(e)
        };
      }
      return {
        res: stopWifi114_res
      };
    },
    stopWifi115: async function stopWifi115() {
      const inputs = [0.1];
      let stopWifi115_res;
      try {
        stopWifi115_res = await invokeApi(uni.stopWifi, true, ...inputs);
      } catch (e) {
        stopWifi115_res = {
          _expectError: true,
          _errMsg: getErrMsg(e)
        };
      }
      return {
        res: stopWifi115_res
      };
    },
    stopWifi116: async function stopWifi116() {
      const inputs = [1];
      let stopWifi116_res;
      try {
        stopWifi116_res = await invokeApi(uni.stopWifi, true, ...inputs);
      } catch (e) {
        stopWifi116_res = {
          _expectError: true,
          _errMsg: getErrMsg(e)
        };
      }
      return {
        res: stopWifi116_res
      };
    },
    stopWifi117: async function stopWifi117() {
      const inputs = [1.1];
      let stopWifi117_res;
      try {
        stopWifi117_res = await invokeApi(uni.stopWifi, true, ...inputs);
      } catch (e) {
        stopWifi117_res = {
          _expectError: true,
          _errMsg: getErrMsg(e)
        };
      }
      return {
        res: stopWifi117_res
      };
    },
    stopWifi118: async function stopWifi118() {
      const inputs = [-9007199254740991];
      let stopWifi118_res;
      try {
        stopWifi118_res = await invokeApi(uni.stopWifi, true, ...inputs);
      } catch (e) {
        stopWifi118_res = {
          _expectError: true,
          _errMsg: getErrMsg(e)
        };
      }
      return {
        res: stopWifi118_res
      };
    },
    stopWifi119: async function stopWifi119() {
      const inputs = [9007199254740991];
      let stopWifi119_res;
      try {
        stopWifi119_res = await invokeApi(uni.stopWifi, true, ...inputs);
      } catch (e) {
        stopWifi119_res = {
          _expectError: true,
          _errMsg: getErrMsg(e)
        };
      }
      return {
        res: stopWifi119_res
      };
    },
    stopWifi120: async function stopWifi120() {
      const inputs = [true];
      let stopWifi120_res;
      try {
        stopWifi120_res = await invokeApi(uni.stopWifi, true, ...inputs);
      } catch (e) {
        stopWifi120_res = {
          _expectError: true,
          _errMsg: getErrMsg(e)
        };
      }
      return {
        res: stopWifi120_res
      };
    },
    stopWifi121: async function stopWifi121() {
      const inputs = [false];
      let stopWifi121_res;
      try {
        stopWifi121_res = await invokeApi(uni.stopWifi, true, ...inputs);
      } catch (e) {
        stopWifi121_res = {
          _expectError: true,
          _errMsg: getErrMsg(e)
        };
      }
      return {
        res: stopWifi121_res
      };
    },
    connectWifi2_assert0: async function connectWifi2_assert0() {
      const inputs = [{
        maunal: false,
        SSID: "Xiaomi_20D0",
        password: "BBB111"
      }];
      const uniAutoTest = {
        isRandom: false,
        inputs
      };
      await startWifi(uniAutoTest);
      let connectWifi2_assert0_res;
      try {
        connectWifi2_assert0_res = await invokeApi(uni.connectWifi, true, ...inputs);
      } catch (e) {
        connectWifi2_assert0_res = {
          _expectError: true,
          _errMsg: getErrMsg(e)
        };
      }
      await stopWifi(uniAutoTest);
      return {
        res: connectWifi2_assert0_res
      };
    },
    getWifiList3_assert0: async function getWifiList3_assert0() {
      const inputs = [];
      const uniAutoTest = {
        isRandom: false,
        inputs
      };
      await startWifi(uniAutoTest);
      let getWifiList3_assert0_res;
      try {
        getWifiList3_assert0_res = await invokeApi(uni.getWifiList, true, ...inputs);
      } catch (e) {
        getWifiList3_assert0_res = {
          _expectError: true,
          _errMsg: getErrMsg(e)
        };
      }
      await stopWifi(uniAutoTest);
      return {
        res: getWifiList3_assert0_res
      };
    }
  }
};
function getErrMsg(e){ return e ? e.message || e : 'There is no error information' }
</script>