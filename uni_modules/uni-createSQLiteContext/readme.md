# uni-createSQLiteContext
### 开发文档
[UTS 语法](https://uniapp.dcloud.net.cn/tutorial/syntax-uts.html)
[UTS API插件](https://uniapp.dcloud.net.cn/plugin/uts-plugin.html)
[UTS 组件插件](https://uniapp.dcloud.net.cn/plugin/uts-component.html)
[Hello UTS](https://gitcode.net/dcloud/hello-uts)

### 注意事项

本插件本质上是一个uni ext api，所以直接使用即可，无需显式调用import导入。

### 使用方法

```javascript
//创建查询的上下文
const sqliteContext = uni.createSQLiteContext({
  name: 'test.db',
});

//执行查询
sqliteContext.selectSql({
  sql: 'select * from test',
  success: function(res) {
    console.log(res);
  },
  fail: function(err) {
    console.log(err);
  }
})

//执行事务
sqliteContext.transaction({
  operation:"begin", //begin,commit,rollback
  success: function(res) {
    console.log(res);
  },
  fail: function(err) {
    console.log(err);
  }
})

//执行增删改
sqliteContext.executeSql({
  sql: 'insert into test values(1, "test")',
  success: function(res) {
    console.log(res);
  },
  fail: function(err) {
    console.log(err);
  }
})

//关闭数据库
sqliteContext.close()

```