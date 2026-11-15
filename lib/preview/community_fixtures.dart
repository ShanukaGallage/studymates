import '../core/models/community_models.dart';

CommunityCatalog createCommunityFixtures({
  bool empty = false,
}) => CommunityCatalog(
  profile: UserProfile(
    id: 'preview-learner',
    displayName: 'Alex (sample)',
    avatarId: 'mint',
    interestIds: ['iot', 'programming'],
  ),
  sigs: empty
      ? []
      : const [
          SigSummary(
            id: 'iot',
            name: 'IoT',
            category: 'Technology',
            description: 'Build small things that connect to a bigger world. Explore sensors, microcontrollers and connected devices together.',
            ownerId: 'preview-owner',
          ),
          SigSummary(
            id: 'programming',
            name: 'Programming',
            category: 'Technology',
            description: 'Practice coding with people working on their next small project.',
            ownerId: 'preview-owner',
          ),
          SigSummary(
            id: 'design',
            name: 'Design for accessible and inclusive everyday learning experiences',
            category: 'Design',
            description:
                'A sample community with a long title and no subgroups yet.',
            ownerId: 'preview-owner',
          ),
        ],
  subgroups: empty
      ? []
      : const [
          SubgroupSummary(
            id: 'esp32',
            sigId: 'iot',
            name: 'ESP32',
            description: 'Start with one sensor, one board and a question worth exploring.',
          ),
          SubgroupSummary(
            id: 'flutter',
            sigId: 'programming',
            name: 'Flutter',
            description:
                'Build your next Android screen with fellow Flutter learners.',
          ),
          SubgroupSummary(
            id: 'dart',
            sigId: 'programming',
            name: 'Dart basics',
            description: 'A quiet starting point. No sample rooms yet.',
          ),
        ],
);

const previewRooms = [
  RoomSummary(
    id: 'first-sensor',
    subgroupId: 'esp32',
    title: 'First Sensor Project',
    occupiedSeats: 3,
  ),
  RoomSummary(
    id: 'quiet-lab',
    subgroupId: 'esp32',
    title: 'Quiet Electronics Lab',
    occupiedSeats: 0,
  ),
  RoomSummary(
    id: 'sensor-club',
    subgroupId: 'esp32',
    title: 'Sensor Study Club',
    occupiedSeats: 6,
  ),
  RoomSummary(
    id: 'first-screen',
    subgroupId: 'flutter',
    title: 'My First Flutter Screen',
    occupiedSeats: 0,
  ),
];
