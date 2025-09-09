import {
  ComponentRef,
  MutableRefObject,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';
import { sortBy } from 'lodash';
import ReadOutlined from '@ant-design/icons/ReadOutlined';
import RightOutlined from '@ant-design/icons/RightOutlined';
import LearningGuide from '@/components/learning/guide';
import { LEARNING } from './guide/utils';
import { useRouter } from 'next/router';
import { Path } from '@/utils/enum';
import {
  useLearningRecordQuery,
  useSaveLearningRecordMutation,
} from '@/apollo/client/graphql/learning.generated';
import { nextTick } from '@/utils/time';
import { ProjectLanguage } from '@/apollo/client/graphql/__types__';
import { useUpdateCurrentProjectMutation } from '@/apollo/client/graphql/settings.generated';

interface LearningConfig {
  id: LEARNING;
  title: string;
  onClick?: () => void;
  href?: string;
  finished?: boolean;
}

const getData = (
  $guide: MutableRefObject<ComponentRef<typeof LearningGuide>>,
  pathname: string,
  saveRecord: (id: LEARNING) => Promise<void>,
  saveLanguage: (value: ProjectLanguage) => Promise<void>,
) => {
  const getDispatcher = (id: LEARNING) => ({
    onDone: () => saveRecord(id),
    onSaveLanguage: saveLanguage,
  });

  const modeling = [
    {
      id: LEARNING.DATA_MODELING_GUIDE,
      title: 'Data modeling guide',
      onClick: () =>
        $guide?.current?.play(
          LEARNING.DATA_MODELING_GUIDE,
          getDispatcher(LEARNING.DATA_MODELING_GUIDE),
        ),
    },
    {
      id: LEARNING.CREATING_MODEL,
      title: 'Creating a model',
      href: 'https://docs.getwren.ai/oss/guide/modeling/models',
      onClick: () => saveRecord(LEARNING.CREATING_MODEL),
    },
    {
      id: LEARNING.CREATING_VIEW,
      title: 'Creating a view',
      href: 'https://docs.getwren.ai/oss/guide/modeling/views',
      onClick: () => saveRecord(LEARNING.CREATING_VIEW),
    },
    {
      id: LEARNING.WORKING_RELATIONSHIP,
      title: 'Working on relationship',
      href: 'https://docs.getwren.ai/oss/guide/modeling/relationships',
      onClick: () => saveRecord(LEARNING.WORKING_RELATIONSHIP),
    },
    {
      id: LEARNING.CONNECT_OTHER_DATA_SOURCES,
      title: 'Connect to other data sources',
      href: 'https://docs.getwren.ai/oss/guide/connect/overview',
      onClick: () => saveRecord(LEARNING.CONNECT_OTHER_DATA_SOURCES),
    },
  ] as LearningConfig[];

  const home = [
    {
      id: LEARNING.SWITCH_PROJECT_LANGUAGE,
      title: 'Feedback form',
      href: 'https://forms.office.com/Pages/ResponsePage.aspx?id=vVOu1SzcGkmrmE3XaUmBkA0mX3Zhn09KmKyxzYcz8s9UM1pZT1lYVTQ1UEZWSkk2Nk42RThWWExQSy4u',
    },
  ];

  if (pathname.startsWith(Path.Modeling)) {
    return modeling;
  } else if (pathname.startsWith(Path.Home)) {
    return home;
  }
  return [];
};

const isLearningAccessible = (pathname: string) =>
  pathname.startsWith(Path.Modeling) || pathname.startsWith(Path.Home);

interface Props {}

export default function SidebarSection(_props: Props) {
  const router = useRouter();
  const [active, setActive] = useState(true);
  const $guide = useRef<ComponentRef<typeof LearningGuide>>(null);
  const $collapseBlock = useRef<HTMLDivElement>(null);

  const { data: learningRecordResult } = useLearningRecordQuery();

  const [saveLearningRecord] = useSaveLearningRecordMutation({
    onError: (error) => console.error(error),
    refetchQueries: ['LearningRecord'],
  });

  const [updateCurrentProject] = useUpdateCurrentProjectMutation({
    onError: (error) => console.error(error),
    refetchQueries: ['GetSettings'],
  });

  const saveRecord = async (path: LEARNING) => {
    await saveLearningRecord({ variables: { data: { path } } });
  };

  const saveLanguage = async (value: ProjectLanguage) => {
    await updateCurrentProject({ variables: { data: { language: value } } });
  };

  const stories = useMemo(() => {
    const learningData = getData(
      $guide,
      router.pathname,
      saveRecord,
      saveLanguage,
    );
    const record = learningRecordResult?.learningRecord.paths || [];
    return sortBy(
      learningData.map((story) => ({
        ...story,
        finished: record.includes(story.id),
      })),
      'finished',
    );
  }, [learningRecordResult?.learningRecord]);

  const collapseBlock = async (isActive: boolean) => {
    if ($collapseBlock.current) {
      const blockHeight = $collapseBlock.current.scrollHeight;
      $collapseBlock.current.style.height = isActive
        ? `${blockHeight}px`
        : '0px';
      await nextTick(300);
      $collapseBlock.current &&
        ($collapseBlock.current.style.transition = 'height 0.3s');
    }
  };

  useEffect(() => {
    const learningRecord = learningRecordResult?.learningRecord;
    if (learningRecord) {
      setActive(
        stories.some((item) => !learningRecord.paths.includes(item.id)),
      );

      const routerAction = {
        [Path.Modeling]: async () => {
          const isGuideDone = learningRecord.paths.includes(
            LEARNING.DATA_MODELING_GUIDE,
          );
          const isSkipBefore = !!window.sessionStorage.getItem(
            'skipDataModelingGuide',
          );
          if (!(isGuideDone || isSkipBefore)) {
            await nextTick(1000);
            $guide.current?.play(LEARNING.DATA_MODELING_GUIDE, {
              onDone: () => saveRecord(LEARNING.DATA_MODELING_GUIDE),
            });
          }
        },
        [Path.Home]: async () => {
          const isGuideDone = learningRecord.paths.includes(
            LEARNING.SWITCH_PROJECT_LANGUAGE,
          );
          const isSkipBefore = !!window.sessionStorage.getItem(
            'skipSwitchProjectLanguageGuide',
          );
          if (!(isGuideDone || isSkipBefore)) {
            await nextTick(1000);
            $guide.current?.play(LEARNING.SWITCH_PROJECT_LANGUAGE, {
              onDone: () => saveRecord(LEARNING.SWITCH_PROJECT_LANGUAGE),
              onSaveLanguage: saveLanguage,
            });
          }
        },
        [Path.Thread]: async () => {
          const isGuideDone = learningRecord.paths.includes(
            LEARNING.SAVE_TO_KNOWLEDGE,
          );
          if (!isGuideDone) {
            await nextTick(1500);
            $guide.current?.play(LEARNING.SAVE_TO_KNOWLEDGE, {
              onDone: () => saveRecord(LEARNING.SAVE_TO_KNOWLEDGE),
            });
          }
        },
        [Path.KnowledgeQuestionSQLPairs]: async () => {
          const isGuideDone = learningRecord.paths.includes(
            LEARNING.KNOWLEDGE_GUIDE,
          );
          if (!isGuideDone) {
            await nextTick(1000);
            $guide.current?.play(LEARNING.KNOWLEDGE_GUIDE, {
              onDone: () => saveRecord(LEARNING.KNOWLEDGE_GUIDE),
            });
          }
        },
      };

      routerAction[router.pathname] && routerAction[router.pathname]();
    }
  }, [learningRecordResult?.learningRecord, router.pathname]);

  useEffect(() => {
    collapseBlock(active);
  }, [active]);

  // Hide learning section if the page not in whitelist
  return (
    <>
      <LearningGuide ref={$guide} />
      {isLearningAccessible(router.pathname) && (
        <div className="border-t border-gray-4">
          <a
            href="https://forms.office.com/Pages/ResponsePage.aspx?id=vVOu1SzcGkmrmE3XaUmBkA0mX3Zhn09KmKyxzYcz8s9UM1pZT1lYVTQ1UEZWSkk2Nk42RThWWExQSy4u"
            target="_blank"
            rel="noopener noreferrer"
            className="px-4 py-1 d-flex align-center cursor-pointer select-none"
          >
            <div className="flex-grow-1">
              <ReadOutlined className="mr-1" />
              Feedback Form
            </div>
            <RightOutlined
              className="text-sm"
              style={{ transform: `rotate(${active ? '90deg' : '0deg'})` }}
            />
          </a>
        </div>
      )}
    </>
  );
}
