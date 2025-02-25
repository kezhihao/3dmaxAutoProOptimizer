rollout BatchOptimizerRollout "批量模型优化工具" width:400 height:330
(
    group "设置"
    (
        spinner spnVertexThreshold "顶点阈值:" range:[1000, 1000000, 50000] type:#integer width:150
        spinner spnReductionPercent "减面百分比:" range:[1, 99, 50] type:#integer width:150
        checkbox chkKeepTexture "保持纹理" checked:true
        checkbox chkForceDelay "添加延迟确保计算" checked:true tooltip:"在计算后添加短暂延迟以确保计算完成"
        button btnOptimize "开始优化" width:150 height:30
        button btnCalculateAll "一键计算已有修改器" width:200 height:30 tooltip:"为所有已添加专业优化修改器的对象执行计算"
    )
    
    group "日志"
    (
        listBox lstLog "" height:15 width:380
        button btnClearLog "清除日志" width:80 height:20 align:#right
    )
    
    fn logMessage msg =
    (
        -- 添加消息到日志列表
        lstLog.items = append lstLog.items msg
        
        -- 自动滚动到底部
        lstLog.selection = lstLog.items.count
        
        -- 强制更新UI
        windows.processPostedMessages()
    )
    
    on btnClearLog pressed do
    (
        -- 清空日志
        lstLog.items = #()
    )
    
    fn isValidGeometry obj =
    (
        -- 检查对象是否为有效的几何体
        isValidNode obj and superClassOf obj == GeometryClass and classOf obj != TargetObject
    )
    
    fn getVertexCount obj =
    (
        -- 简化的顶点数获取函数
        local vertCount = 0
        
        if classOf obj == Editable_Poly then
            vertCount = polyop.getNumVerts obj
        else if classOf obj == Editable_Mesh then
            vertCount = obj.numverts
        else
            try (vertCount = obj.mesh.numverts) catch (vertCount = 0)
            
        return vertCount
    )
    
    fn calculateProOptimizer proOpt obj forceDelay:true =
    (
        try (
            -- 确保修改器为当前选中对象
            modPanel.setCurrentObject proOpt
            
            -- 获取当前计算状态
            local currentState = proOpt.Calculate
            
            -- 设置计算属性为true触发计算
            proOpt.Calculate = true
            
            -- 强制重绘确保UI更新
            forceCompleteRedraw()
            
            -- 如果需要延迟，添加短暂等待
            if forceDelay then
            (
                -- 处理所有待处理消息
                windows.processPostedMessages()
                -- 短暂延迟
                sleep 0.1
            )
            
            return true
        ) catch (
            local errorMsg = getCurrentException()
            logMessage ("计算错误 (" + obj.name + "): " + errorMsg)
            return false
        )
    )
    
    on btnCalculateAll pressed do
    (
        -- 清空日志
        lstLog.items = #()
        
        -- 计数器
        local objectsWithModifier = 0
        local calculatedObjects = 0
        
        -- 显示开始信息
        logMessage ("开始查找并计算所有已添加专业优化修改器的对象...")
        
        -- 遍历所有对象
        for obj in objects do
        (
            if isValidNode obj then
            (
                -- 查找是否有ProOptimizer修改器
                for i = 1 to obj.modifiers.count do
                (
                    local mod = obj.modifiers[i]
                    if classOf mod == ProOptimizer then
                    (
                        objectsWithModifier += 1
                        
                        -- 执行计算
                        if calculateProOptimizer mod obj forceDelay:chkForceDelay.checked then
                        (
                            calculatedObjects += 1
                            logMessage (obj.name + " - 专业优化修改器计算完成")
                        )
                        
                        -- 只处理第一个找到的ProOptimizer
                        exit
                    )
                )
            )
        )
        
        -- 显示完成信息
        logMessage ("完成! 找到 " + objectsWithModifier as string + " 个带有专业优化修改器的对象")
        logMessage ("成功计算 " + calculatedObjects as string + " 个对象")
    )
    
    on btnOptimize pressed do
    (
        -- 清空日志
        lstLog.items = #()
        
        -- 获取设置
        local vertexThreshold = spnVertexThreshold.value
        local reductionPercent = spnReductionPercent.value
        local keepTexture = chkKeepTexture.checked
        local forceDelay = chkForceDelay.checked
        
        -- 准备批量处理的对象数组
        local objectsToProcess = #()
        local vertexCounts = #()
        
        -- 收集需要处理的对象
        for obj in objects do
        (
            if isValidNode obj and superClassOf obj == GeometryClass and classOf obj != TargetObject do
            (
                local vertCount = getVertexCount obj
                if vertCount > vertexThreshold then
                (
                    append objectsToProcess obj
                    append vertexCounts vertCount
                )
            )
        )
        
        -- 显示开始信息
        local totalObjects = objectsToProcess.count
        logMessage ("开始处理 " + totalObjects as string + " 个对象...")
        
        -- 批量处理对象
        local processedObjects = 0
        
        for i = 1 to objectsToProcess.count do
        (
            local obj = objectsToProcess[i]
            local vertCount = vertexCounts[i]
            
            -- 确保对象是可编辑的
            if not (canConvertTo obj Editable_Poly) then
            (
                logMessage ("无法处理 " + obj.name + "，不是可编辑几何体")
                continue
            )
            
            -- 只有在需要时转换为可编辑多边形
            if classOf obj != Editable_Poly then
                convertTo obj Editable_Poly
            
            -- 添加ProOptimizer修改器
            local proOpt = ProOptimizer()
            addModifier obj proOpt
            
            -- 设置参数
            proOpt.VertexPercent = reductionPercent
            
            -- 尝试设置保持纹理相关的属性
            try ( proOpt.PreserveUVs = keepTexture ) catch()
            try ( proOpt.PreserveMaterial = keepTexture ) catch()
            try ( proOpt.PreserveTextures = keepTexture ) catch()
            
            -- 执行计算
            local calculationSuccess = calculateProOptimizer proOpt obj forceDelay:forceDelay
            
            if calculationSuccess then
                logMessage (obj.name + " 已优化: " + vertCount as string + " 顶点减少到 " + (vertCount * reductionPercent / 100.0) as string)
            
            -- 每10个对象更新一次日志，减少UI更新开销
            if mod i 10 == 0 or i == objectsToProcess.count then
                logMessage ("已处理: " + i as string + " / " + totalObjects as string)
            
            processedObjects += 1
        )
        
        -- 显示完成信息
        logMessage ("完成! 已优化 " + processedObjects as string + " 个对象")
    )
)

-- 创建对话框
createDialog BatchOptimizerRollout 