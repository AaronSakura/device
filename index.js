// 简单的前端入口文件
// 主要用于 GitHub Pages 部署时的前端支持

// 确保在 GitHub Pages 上能正确处理路由
if (typeof window !== 'undefined') {
    // 检测主题偏好并应用
    const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    const savedTheme = localStorage.getItem('theme');
    
    if (savedTheme === 'dark' || (!savedTheme && prefersDark)) {
        document.documentElement.classList.add('dark');
    }
    
    // 主题切换功能
    const themeToggle = document.getElementById('theme-toggle');
    if (themeToggle) {
        themeToggle.addEventListener('click', function() {
            document.documentElement.classList.toggle('dark');
            localStorage.setItem('theme', document.documentElement.classList.contains('dark') ? 'dark' : 'light');
        });
    }
}

// 导出一个简单的函数以便在其他地方使用
export function initPage() {
    console.log('个人主页已初始化');
}