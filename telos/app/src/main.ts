import "./style.css";
import { renderHome } from "./views/home";
import { renderChecklistDetail, renderChecklistList } from "./views/checklist";
import { renderSlidesEdit, renderSlidesList } from "./views/slides";
import { renderGoalsDetail, renderGoalsList } from "./views/goals";
import { renderBriefEdit, renderBriefList } from "./views/brief";
import { renderPositioningEdit, renderPositioningList } from "./views/positioning";
import { renderRetroEdit, renderRetroList } from "./views/retro";
import { renderEstimateEdit, renderEstimateList } from "./views/estimate";
import { renderProposalEdit, renderProposalList } from "./views/proposal";
import { renderDecisionsEdit, renderDecisionsList } from "./views/decisions";
import { renderChangesEdit, renderChangesList } from "./views/changes";
import { renderSettings } from "./views/settings";

const app = document.querySelector<HTMLElement>("#app")!;

function route(): void {
  const [section = "", id = ""] = (location.hash || "#/").replace(/^#\//, "").split("/");

  document.querySelectorAll("[data-nav]").forEach((a) => {
    a.classList.toggle("active", a.getAttribute("data-nav") === section);
  });

  switch (section) {
    case "checklist":
      if (id) renderChecklistDetail(app, id);
      else renderChecklistList(app);
      break;
    case "slides":
      if (id) renderSlidesEdit(app, id);
      else renderSlidesList(app);
      break;
    case "goals":
      if (id) renderGoalsDetail(app, id);
      else renderGoalsList(app);
      break;
    case "brief":
      if (id) renderBriefEdit(app, id);
      else renderBriefList(app);
      break;
    case "positioning":
      if (id) renderPositioningEdit(app, id);
      else renderPositioningList(app);
      break;
    case "retro":
      if (id) renderRetroEdit(app, id);
      else renderRetroList(app);
      break;
    case "estimate":
      if (id) renderEstimateEdit(app, id);
      else renderEstimateList(app);
      break;
    case "proposal":
      if (id) renderProposalEdit(app, id);
      else renderProposalList(app);
      break;
    case "decisions":
      if (id) renderDecisionsEdit(app, id);
      else renderDecisionsList(app);
      break;
    case "changes":
      if (id) renderChangesEdit(app, id);
      else renderChangesList(app);
      break;
    case "settings":
      renderSettings(app);
      break;
    default:
      renderHome(app);
  }
  window.scrollTo(0, 0);
}

window.addEventListener("hashchange", route);
route();
