// make use of data recived using GET parameters
let myurl = new URL(window.location.href)
let pkg_list = myurl.searchParams.get('pkg_list')   // list of all packages
let outdated = myurl.searchParams.get('outdated')   // list of outdated packages seperated by semicolon
let img_width = parseInt(myurl.searchParams.get('width'))   // image width to render
let img_height = parseInt(myurl.searchParams.get('height')) // image height to render
let background_color = myurl.searchParams.get('bg_color')   // background color
// get the span element where packages are displayed
// this is used by the functions bellow
var container = document.getElementById('container')    // container used for better dimensions control
var pkg_div = document.getElementById('packages')   // hosts package list to render

/**
 * Insert package list to the page for rendering and manipulation
 * @param {string} pkg_list 
 */
function insert_pkg_list(pkg_list){
    pkg_div.innerText = pkg_list
}
/**
 * Resize packages font and line spacing to perfectly fit desired dimensions
 * @param {number} width 
 * @param {number} height 
 */
function resizeFont(width, height){
    // all sizes are in pixels (px)
    let step_size = 0.1 // font size change each step
    let size=1  // initial font size
    container.style.maxWidth = width
    container.style.maxHeight = height
    // find bestfit font size
    pkg_div.style.fontSize = size + 'px'
    while(pkg_div.getBoundingClientRect().width <= width && pkg_div.getBoundingClientRect().height <= height){
        size += step_size
        console.log(size + 'px')
        pkg_div.style.fontSize = size + 'px'
    }
    size -= step_size
    pkg_div.style.fontSize = size + 'px'
    pkg_div.style.textAlign = 'justify'
    // find bestfit line spacing
    let linespace = 0
    while(pkg_div.getBoundingClientRect().width <= width && pkg_div.getBoundingClientRect().height <= height){
        linespace += step_size
        console.log(linespace + 'px')
        pkg_div.style.lineHeight = linespace + 'px'
    }
    linespace -= step_size
    pkg_div.style.lineHeight = linespace + 'px'
}
/**
 * Mark outdated packages with the <old> tag based on a list of package names seperated by semicolon
 * @param {string} pkg_names 
 */
function mark_outdated(pkg_names){
    let old_pkg = pkg_names
    old_pkg.split(';').forEach(pkg => {
        let re = new RegExp('(' + pkg + ')',"g")
        pkg_div.innerHTML = pkg_div.innerHTML.replace(re, "<old>$1</old>")
    })
}
/**
 * Sets styling elements based on theme and color
 * @param {string} bg_color background color name supported by html
 */
function updateTheme(bg_color){
    document.body.style.backgroundColor = bg_color;
}

// generate the page
updateTheme(background_color)
insert_pkg_list(pkg_list)
resizeFont(img_width, img_height)
mark_outdated(outdated)