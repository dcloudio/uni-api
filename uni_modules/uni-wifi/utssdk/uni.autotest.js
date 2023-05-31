export function startWifi() {
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

export function stopWifi() {
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
