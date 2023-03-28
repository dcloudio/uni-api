function startWifi() {
	return new Promise((resolve, reject) => {
		uni.startWifi({
			success: () => {
				console.log('startWifi success');
				resolve()
			},
			fail: () => {
				console.log('startWifi fail');
				reject()
			}
		})
	})
}

function stopWifi() {
	return new Promise((resolve, reject) => {
		uni.stopWifi({
			success: () => {
				console.log('stopWifi success');
				resolve()
			},
			fail: () => {
				console.log('stopWifi success');
				fail()
			}
		})
	})
}


module.exports = {
	startWifi,
	stopWifi
}
