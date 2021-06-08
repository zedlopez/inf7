function toggle_details() {
   var openness, toggle_link;
   toggle_link = document.getElementById("toggle");
   openness = toggle_link.classList.toggle("open");
document.querySelectorAll("details.full-example").forEach(detail => { if (openness) { detail.setAttribute("open", true); } else { detail.removeAttribute("open");} });
   toggle_link.innerText = (openness ? "Close" : "Open") + " all examples";
}


<%== Inf7::Template[:copycode].render %>
<%== Inf7::Template[:open_example].render %>
<%== Inf7::Template[:navbar_js].render %>


function update_links() {
  add_bar(true);
}

document.addEventListener("DOMContentLoaded", update_links);
